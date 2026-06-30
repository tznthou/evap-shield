# Investigating Claude Code's tool-argument evaporation bug: the VH1 parser, a two-byte patch, and what it doesn't fix

*A field report on root-causing, patching, and verifying the bug where tool calls silently lose their arguments, with an honest account of what the fix does and does not cover.*

*Time anchor: the core binary-level findings are as of Claude Code 2.1.179 (2026-06-17), re-checked on every build through 2.1.196 (§7). The methods below let you re-check any later build yourself.*

## TL;DR

- **The bug is real and unfixed upstream.** Tool calls intermittently arrive with their arguments collapsed to `{}`. Three open issues track it (#62123, #67765, #63583); none had a maintainer reply as of 2026-06-24.
- **Root cause (one sub-shape of it):** a client-side streaming partial-JSON parser drops a string token when a value is cut across a streaming chunk boundary, collapsing the tool input to `{}`. We reached this independently; @in4mer filed the same analysis first in #67765.
- **It is patchable on the client.** Because this sub-shape lives in the client parser, a single two-byte binary patch (`!Y`→`!0`) stops the token from being discarded. As far as we found, evap-shield is the only tool that patches the parser itself rather than cleaning up after the fact.
- **The patch is verified correct by a white-box unit test: 760 truncation cases, 0 regressions.** It compares the original and patched parser byte-for-byte at every streaming cut point.
- **Official builds through 2.1.196 have not fixed it.** A 178↔179 binary diff shows the parser byte unchanged; 2.1.181's Bun 1.4 upgrade reshuffled the minified names while leaving the parser logic identical; and every build since — 2.1.183, 185, 186, 187, 190, 191, 193, 195, 196 — is byte-for-byte identical at the parser site once identifiers are normalized (§7). The changelog's "partial responses preserved" is a higher-layer graceful-degradation feature, not a parser fix.
- **Honest boundary:** the patch covers one corner of a larger bug cluster. A second camp attributes other failures in the same cluster to the model emitting malformed markup, which a client patch cannot touch. We could not reproduce one of @in4mer's four points on 2.1.179. And the parser's primary failure path is, by construction, not reachable from a server-side mock, so the unit test rather than an end-to-end test is what verifies the fix.

## 1. The symptom: a tool call with no arguments

While writing this investigation, the tool I was using produced a clean example of the failure family it describes. A step was marked `completed`, but the content that step was supposed to deliver never appeared. The shell of the action was there; the payload was gone. My first instinct was that I had just been bitten by the bug under study.

I was wrong, and how I found out is the point. A single screenshot, `API Error: 529 Overloaded`, showed the real cause: a server-side interruption that cut the response stream mid-flight, between one block and the next. Not the parser bug. Not the agent skipping a step. A third cause I had not even listed.

That matters because the cause I jumped to and the cause that actually happened produce the *same observable symptom*: an action that reports success while its payload silently disappears. Across this whole bug cluster that is the recurring trap. The symptoms converge, the root causes do not, and you cannot tell them apart without evidence. (The 529 interruption is exactly the connection-drop shape that Section 6 shows *bypasses* the parser bug rather than triggering it.)

It happened a second time as I was committing this very writeup: a tool call came back *malformed and could not be parsed*, which is the exact headline symptom of #62123. This time it really looked like the bug, except the retry succeeded immediately, whereas #62123's signature is that the retry *also* fails. Same symptom, opposite tell, and once again not the cause I was about to write about.

The bug this report is about looks like this: a model decides to call a tool, the call goes out, and its `input` arrives as `{}`. The model reached for a tool and came back empty-handed. The same root cause surfaces downstream as three distinct symptoms:

- `input: {}`: the tool_use block is present but the arguments are empty. This is the main case in #67765.
- the tool_use block disappears entirely: `stop_reason` is `tool_use` but no block follows. This matches the title of #63583 verbatim.
- a silent stall: empty text, with `stop_reason` not set to `tool_use`.

It is real and not rare: #62123 has 57 comments, and both #67765 and #63583 carry a `has repro` label. I won't claim a frequency beyond that. There is no hard data for one, and the bug is intermittent by nature.

## 2. Two camps, no upstream fix, and nobody patching it

The bug has two competing root-cause theories, and they are not really fighting over the same failure; each fits a different sub-shape of the cluster.

- **Camp A, client parser.** A streaming partial-JSON parser drops tokens when a value is split across chunks, collapsing the input to `{}`. This is @in4mer's position and ours. Because it lives in the client, it can be patched there.
- **Camp B, model-side.** The model emits malformed legacy markup (bare invoke tags missing their prefix); the client is only reporting what it received, not producing the error. This cannot be fixed client-side; it can only be recovered from or degraded around.

This is not a question of one camp being wrong. The two likely describe different routes into the same observable failure, and Section 8 returns to where they part ways. It also happens that the people who diagnose it as a client parser bug are the ones who go on to patch the binary.

Upstream, nothing has moved. All three issues are open with zero maintainer replies, and none was touched after 2.1.179 shipped on the same day. Even the triage labels are split: `area:model` on #62123 and #63583, `area:core` and `area:mcp` on #67765. I'll note the split and leave the reading of it open.

The tooling around the bug is real but aimed elsewhere. @in4mer has the sharpest analysis of the lot but no tool. `claude-code-unpoison` rewinds a poisoned session after the fact so you can resume cleanly. `cc-safe-setup` is a large hook safety kit that classifies incidents and helps recover. None of them touches the parser.

Which leaves the question this report answers: can the client side actually *fix* this, not just recover, for Camp A's sub-shape? Yes, with a two-byte patch. The rest of this report is the evidence for that claim and the boundary around it.

## 3. Root cause: the VH1 streaming parser

The tool input passes through a four-layer pipeline, `JSON.parse(kH1(vH1(bFH(VH1(H)))))` (minified names, version-specific). VH1 is the streaming tokenizer, and it is where the bug lives. When a string value is split across streaming chunks and the closing quote has not arrived yet, VH1 discards the in-flight string token instead of holding it. The cascade collapses, and the final input parses to `{}`.

@in4mer's #67765, which he titled "accumulator shear," lays out the same first three stages: the parser drop, a secondary `?? {}` fallback that turns the broken parse into an empty object, and a per-tool cache that makes the empty result stick. He shipped a repro with it. We arrived at the same three stages independently, from our own extraction of the binary.

The fix, in concept, is to make the parser keep the incomplete string token rather than discard it, so the cascade never breaks. In the binary that is a two-byte change of the same length, with no offset shift. I'm deliberately not walking through the patching procedure here. The mechanism is the point of this section, and the tool in the repo carries its own safety rails for anyone who wants the rest.

## 4. Does the patch actually work? 760 tests, 0 regressions

The verification is white-box. Extract the four-layer pipeline, run the original and patched parser side by side, and compare their output byte-for-byte at every streaming truncation boundary.

**760 tests, 0 regressions.** Zero-cost, deterministic, no real API calls. The patch changes behaviour only in the truncated-string intermediate state; on the happy path the two parsers are byte-identical. That last part is what makes the change safe to ship: it stays inert unless the exact failure condition occurs.

Why a *unit* test is the verification that counts, rather than something end-to-end, is the subject of Section 6. Hold the thought.

## 5. Is it safe to patch a running binary?

The scare came first: a freshly patched binary exited 137 (SIGKILL) on launch. The obvious hypothesis was that the byte patch broke the Developer ID signature and AMFI rejected it.

A control experiment falsified that. The factory binary copied to a fresh path ran fine (exit 0). The *same bytes* written in place over the running inode exited 137, regardless of whether the signature was valid. The real cause is overwriting an inode that is currently mmap'd and executing: the on-disk code pages diverge from the running image, and AMFI SIGKILLs the next exec of that inode. It also explains why the patch only takes effect after a full restart.

The fix has three parts, and dropping any one re-bricks the binary:

1. **Ad-hoc re-sign after patching.** The byte change invalidates the Developer ID signature. With no Anthropic private key, an ad-hoc signature is the only local option, and it is deterministic (same input, same hash).
2. **Smoke-test a copy on a fresh path**, never the live inode. Otherwise the test re-triggers the 137 and the patch can never install.
3. **Size-check against the pre-resign size**, because the ad-hoc re-sign changes the binary's size.

On 2.1.179, live: patched, runs (exit 0, no brick), and rolls back cleanly. The binary shrinks by 1.28 MB in the process (226,082,208 → 224,766,816 bytes). That is the factory signature section being swapped for a smaller ad-hoc one, not the patch; the parser change itself is two same-length bytes.

The honest cost: a native update overwrites the patch. Every `claude update` returns the binary to its unpatched state, and the patch has to be re-applied. "A full restart" can itself be subtle: if a launcher or wrapper keeps the binary resident, switching windows or sessions may not release the running inode — check with `lsof <binary>` that nothing still holds it, both before patching and before expecting the patch to take effect. You are modifying a signed, vendored binary on your own machine; there is a backup, there are safety checks, and it is still at your own risk. This is defensive research on locally-installed software, not an invitation to go modifying binaries casually.

## 6. What we could not prove, and why

This section earns the rest of the report. Three honest limits.

**The parser's primary failure path is not reachable from a server-side mock.** We built a zero-cost end-to-end harness, a local mock server feeding truncated streams to the real binary, to watch the bug end to end. It could not trigger the primary path. Three different constructions all bypassed it: dropping the connection mid-stream made the transport retry instead of finalizing (the same connection-drop shape as the 529 in Section 1); an external interrupt aborted the whole operation; and a clean truncation fell through to the *secondary* `?? {}` fallback, not the primary parser drop. The primary path requires the client to actively commit a mid-stream partial buffer, something only the interactive TUI's abort-and-finalize handler does. So an end-to-end test *cannot* verify this patch; the unit test from Section 4 is the only thing that can. That is a structural boundary of the harness, not a missing tool.

**The hook layer guards less than it looks.** evap-shield ships a PreToolUse hook alongside the patch. Tested end to end: for built-in tools, an empty `{}` input is caught by Claude Code's own `InputValidationError` before the hook is ever called, so the hook is redundant there. For MCP tools it is different, and this is the one gap we have closed since the earlier writeup: we have now verified, on 2.1.179, that an MCP tool's `{}` input *does* reach the hook and evap-shield blocks it. (MCP tool schemas live server-side, so the client's `InputValidationError` does not fire first.) This rests on the client's validation *ordering* — MCP inputs are validated after the hook, built-ins before — which any build could change; unlike the parser site (Section 7), we checked it once on 2.1.179 and have not re-verified it on 181/183. There is a third shape: the tool_use block vanishes after the call already executed. The PreToolUse hook cannot catch that at all, because it runs before execution. The binary patch, not the hook, is the layer that covers the parser at its source.

**We could not reproduce one of @in4mer's four points.** His #67765 lists a fourth item: a top-level backslash handler that consumes two characters and drops the next `{` / `"` / `,`. Pulling the tokenizer out of the 2.1.179 binary and running it on real input, a top-level `\` followed by any of those tokenizes with nothing dropped. The handler skips only a single stray character. I want to be precise about what this is: *we could not reproduce his fourth point on 2.1.179*, which is not a refutation. He analyzed 2.1.173; the code may have changed between versions, or we may be looking at a different path than the one he meant. His first three points we reached independently and agree with. The shape we can reliably reproduce is the string-handler drop, and that is the one the patch targets.

## 7. Did the official 2.1.179 fix it?

The method matters more than the verdict, because the method outlasts any single version. The binary is a bun-compiled Mach-O with the JS bundle minified onto enormous single lines, so you can't diff a beautified file. Two anchored diffs do the job: (1) find the parser's `push` call, pull the bytes around it, and check whether the preceding bytes read `,!Y)` (original) or `,!0)` (patched); (2) extract short strings (`strings -a -n 6`, drop the long lines, sort-unique) and `comm` the two versions to surface what the newer build added.

The verdict, 178↔179: the parser byte is unchanged, and 179 still ships the original `,!Y)`. What 179 *did* add is all higher-layer: a "finalizing partial response" path, a partial-finalized telemetry event, and a friendly "connection closed mid-response" message, all operating at the SSE-block level rather than the JSON-token level. The changelog line "mid-stream connection drops: partial responses preserved" is graceful degradation, not a parser fix.

One counterintuitive consequence: now that the client preserves a partial response and feeds it onward, that incomplete JSON still has to pass through the unpatched parser. If anything, that could make the parser bug *easier* to hit on the connection-drop path, not harder. The official change moved the ball closer to the bug without fixing it.

Time anchor again: this is 2.1.179 on 2026-06-17. Re-run the two diffs on any later build to check it for yourself.

**Update, 2.1.181 (2026-06-18).** I re-ran both diffs on the next build (2.1.180 was skipped). The verdict holds — the parser is still unpatched — and the *way* it held is the point. A literal search for the old `,!Y)q.push` now finds nothing, yet the parser logic is structurally identical; only the names changed. The cause is in the changelog: the bundled Bun runtime was upgraded to 1.4, and the new bundler reshuffled the entire minified identifier space. The string handler's variables went from `Y/q/$` (2.1.179) to `l/n/a` (2.1.181), and the factory binary dropped from 226,082,208 to 215,193,056 bytes (~11 MB) — a new minifier, not a parser change. This is the section's thesis made concrete: a fixed byte-pattern rots across builds, so the durable anchor is the *structure* — `,!<flag>)<recv>.push({type:"string",value:<acc>})` — not the literal bytes. The same two-byte fix still applies; only the way you locate it must be version-agnostic.

**Update, 2.1.183 (2026-06-19).** Two builds on (2.1.182 was skipped), the verdict still holds — and this time the easy way. With Bun already at 1.4 since 2.1.181, the minifier reshuffled nothing: the string handler's variables are still `l/n/a`, and once identifiers are normalized the parser site is byte-for-byte identical to 2.1.181 — the same `,!l)n.push({type:"string",value:a})`. None of 2.1.183's sixteen changelog entries touch tool-call parsing (the nearest, "re-prompt once when a turn returns only a thinking block," is about *no output*, not *evaporated arguments* — a different failure). The structural anchor matched `!l`→`!0` on the first try, no script change. Across three consecutive builds — 2.1.179, 181, 183 — the parser is unpatched upstream.

**Update, 2.1.185 (2026-06-22).** (2.1.184 skipped.) Same verdict, same `,!l)n.push({type:"string",value:a})` with identifiers unchanged — but the parser site has drifted 64 bytes down the file (192,250,754 → 192,250,818), so this is a genuinely new build with the parser frozen in place, not a recompiled copy. The 78 new short strings are all sandboxing, an agent-proxy, cloud sessions, OAuth and MCP governance; none touch the JSON parser.

**Update, 2.1.186 (2026-06-23).** The first back-to-back version number (185→186, breaking the 182/184 skip pattern), and the strongest signal so far. Unlike the frozen-size rebuilds before it, 186 is a substantial build: the factory binary grew 858,624 bytes and the parser site moved almost a megabyte (to 193,217,884). That new code is all sandboxing, an egress agent-proxy, managed-agents, MCP resource tools, plugin governance — even a prompt for a "security monitor for autonomous AI coding agents." Anthropic shipped ~858 KB of real new code and still did not touch the parser. The same day, a third party independently filed #70196 (takepan, 2.1.186, macOS/iTerm) with the textbook symptom — "could not be parsed (retry also failed)," the error array itself evaporated to `[]` — confirming 186 is still affected from the outside. It was later marked `duplicate` of the main thread and tagged `area:model`, the same triage split noted in Section 2.

**Update, 2.1.187 (2026-06-24).** The second back-to-back number (186→187). This time the factory binary shrank 817,184 bytes, yet the ±260-byte window around the parser site matches raw — byte-for-byte, without even normalizing identifiers. The build is real, not a reshuffle: 39 strings added and 26 removed — a `/toggle-memory`→`/pause-memory` rename, usage-credit billing copy, sandbox and credential fields, GitHub Actions, an MCP idle timeout — none in the parser. That makes four effective builds since 2.1.181 (183, 185, 186, 187), none of them a fix, across two weeks of near-daily releases.

**Update, 2.1.191 (2026-06-25).** Two more builds, both unfixed. After 2.1.187, Anthropic shipped 2.1.190 (2026-06-24; 188 and 189 were skipped) and then 2.1.191. The parser site stays frozen at `,!l)n.push({type:"string",value:a})`, raw-identical to 2.1.187 across the window. The factory binary grew 215,994,048 → 217,273,568 (190) → 219,856,224 (191), and the site drifted to 197,303,261 in 191. A strings diff attributes the growth to a Bun runtime upgrade (HTTP agent/proxy/tunnel, async_hooks) and the workflow/agent subsystem; 2.1.191's eighteen changelog entries (/rewind, background agents, sandboxing, MCP retry, a 37% CPU cut) touch none of the tool-call parser. 2.1.190 was a brief ~8-hour unpatched window — never patched before 191 superseded it — and 191 was re-patched and verified by byte, inode, and launch timing. These are the fifth and sixth effective builds since 2.1.181 to leave VH1 unfixed.

**Update, 2.1.193 (2026-06-26).** The seventh. Claude Code updated 2.1.191 → 2.1.193 (2.1.192 skipped). The factory binary grew another 2.39 MB (219,856,224 → 222,248,240) and the parser site drifted 989,822 bytes (197,303,261 → 198,293,083), yet the ±120-byte window around it is byte-for-byte identical to 2.1.191 with no normalization needed — the raw-frozen streak now runs unbroken from 2.1.187. The structural anchor still finds exactly one vulnerable site in the whole binary. A strings diff puts all 3,701 new short strings elsewhere: Bun runtime stream builtins (`@putByIdDirectPrivate(readableStreamController…)`, an HTTP "Parse Error" path), a workflow-VM sandbox (an `attacker-reachable` clone walker with a propagation invariant), and a feedback-report UI template — none of it the character-level string tokenizer. The version-agnostic patcher re-applied with no script change (`!l`→`!0`, one byte; original `f7513a30…` → patched `cadbe992…`), verified on disk (bug 0 / fix 1), by signature, by the running session's mmap'd inode (this very session), and by launch timing — patched dogfooding. That is seven effective builds since 2.1.181 (183, 185, 186, 187, 190, 191, 193), none of them a fix.

**Update, 2.1.195 (2026-06-27).** The eighth. Claude Code updated 2.1.193 → 2.1.195 (2.1.194 skipped). The factory binary grew 2.43 MB (222,248,240 → 224,682,640) and the parser site drifted 3,313,810 bytes (198,293,083 → 201,606,893), yet the ±120-byte window around it is byte-for-byte identical to 2.1.193 with no normalization needed — even the preceding escape-scan loop is untouched, and the raw-frozen streak now runs unbroken from 2.1.187 across four releases. The structural anchor still finds exactly one vulnerable site in the whole binary. A strings diff puts all 4,746 new short strings elsewhere: an LLM gateway/proxy relay (re-emitting Anthropic-shaped `text/event-stream`, Bedrock's AWS binary event-stream, stripping the client's `Authorization`), a JWE/JWK/OAuth credential layer, the agent/workflow subsystem, voice streaming, sandboxing, and a Storybook adapter — none of it the character-level string tokenizer, the same theme as 187→191→193. The version-agnostic patcher re-applied with no script change (`!l`→`!0`, one byte; original `8b45adad…` → patched `84c24c42…`), verified on disk (bug 0 / fix 1), by signature, by the running session's mmap'd inode (this very session), and by launch timing — patched dogfooding. That is eight effective builds since 2.1.181 (183, 185, 186, 187, 190, 191, 193, 195), none of them a fix.

**Update, 2.1.196 (2026-06-30).** The ninth. Claude Code updated 2.1.195 → 2.1.196 (consecutive). The factory binary grew 1.1 MB (224,682,640 → 225,782,608) and the parser site drifted 981,275 bytes (201,606,893 → 202,588,168), yet the ±120-byte window around it is byte-for-byte identical to 2.1.195 with no normalization needed — the fifth consecutive raw-frozen build, unbroken from 2.1.187. The structural anchor still finds exactly one vulnerable site in the whole binary. A strings diff puts all 10,262 added (and 7,616 removed) short strings elsewhere: agent/plugin/MCP/skill/workflow/sandbox/OAuth/Bedrock subsystems — none of it the character-level string tokenizer. The version-agnostic patcher re-applied with no script change (`!l`→`!0`, one byte; original `6fc6e61a…` → patched `7fed84d2…`), verified on disk (bug 0 / fix 1), by signature, by the running session's mmap'd inode (this very session), and by launch timing — patched dogfooding. That is nine effective builds since 2.1.181 (183, 185, 186, 187, 190, 191, 193, 195, 196), none of them a fix.

**Automating the re-check.** We have since wired this into a `SessionStart` hook (`check-update.sh`) so it runs on its own, because Section 5's cost recurs on every update: each native `claude update` overwrites the patch, raising "did this build fix it, and must I re-patch?" anew. It stays near-instant by not diffing on every launch — a stat-only fingerprint (resolved path, size, mtime) of the live binary gates the work; an unchanged fingerprint means no update happened, so nothing could have been overwritten, and it exits silently. Only a changed binary triggers the full anchored scan from this section, which reports `vulnerable` (re-patch), `patched` (quiet), or `unknown` (pattern gone — possibly fixed upstream, verify). It fails open throughout.

## 8. Honest scope: one corner of the cluster

evap-shield's patch covers Camp A's sub-shape. It is not the whole cluster. The community splits tool-call parsing failures into several sub-patterns, and Camp B's malformed-markup route is a different one. That is exactly why, in our own harness, the patched binary still produced `{}` on a clean truncation: that path hits the secondary fallback, not the primary parser drop (Section 6). The fix is real. It is one corner.

The rest of the landscape is complementary, not competing. `claude-code-unpoison` rewinds a poisoned session after the fact. `cc-safe-setup` classifies incidents and recovers at the hook layer. @in4mer's #67765 is the sharpest root-cause writeup of the bunch. Each covers a piece. evap-shield's piece is patching the one parser sub-shape we could reliably reproduce and verify: no more than that, and that much for real.

## 9. Who runs the verification we couldn't

One sentence in Section 6 is worth returning to: the unreachable end-to-end test is "a structural boundary of the harness, not a missing tool." That is true — and, on its own, it closes a question it should open. Set it beside the other sentence from that section — the primary path "requires the client to actively commit a mid-stream partial buffer, something only the interactive TUI's abort-and-finalize handler does" — and a conclusion the report has carried without stating falls out.

If the primary path fires only in a live TUI session, and no controlled harness can reach it, then the only place the patch's primary-path efficacy can ever be observed is a real session on a real machine. Ours, or yours. The unit test proves the byte-level behaviour is correct (Section 4); it cannot prove the fix lands on the path that bit you in production, because that path does not exist inside the test. So "a structural boundary of the harness" is the honest engineering description, and it is at the same time a transfer: the end-to-end verification we could not run does not disappear, it moves downstream to whoever runs the patched binary. Each person who patches is, on the primary path, the first-line observer of an outcome we never got to watch.

I'd rather name that than leave it in neutral terms. It is not a confession either: the byte-level change is verified at the unit layer (Section 4), the patch is fully reversible with a backup and safety checks (Section 5), and upstream has shipped no fix through 2.1.196 (Section 7). The observer is informed and the risk is reversible. But informed is the precise word, not proven. If you patch, you are not consuming an efficacy demonstrated end to end; on the primary path, you are where that proof finally happens.

## References

- Issues: `anthropics/claude-code` #62123, #67765 (root cause, @in4mer), #63583
- evap-shield: `github.com/tznthou/evap-shield` (PreToolUse hook + binary patch)
- Parser patch pattern, 2.1.179: `,!Y)` → `,!0)` (same length, no offset shift). Version-specific: the minified names reshuffle between builds (§7), so locate by the structure `…push({type:"string",value:…})`, not the literal bytes.
- Verification: white-box unit test, 760 truncation cases, 0 regressions
- Binary-diff method: parser-byte anchor + short-string `comm` (Section 7)
