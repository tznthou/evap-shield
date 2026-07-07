# Changelog

[中文](CHANGELOG_ZH.md)

All notable changes to evap-shield are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). This project groups changes by date rather than semantic version — it's a script toolkit, not a registry-published package.

## 2026-07-07

### Changed

- Bumped the tested badge to **2.1.202**. Claude Code updated 2.1.201 → 2.1.202 (consecutive). The structural anchor still finds exactly one vulnerable site in the factory binary (bug 1 / fix 0), and the `e[++t]` character-scan loop signature still appears 7 times — but for the first time since 2.1.181, the window around the site is not raw-identical: 2.1.201's `,!l)n.push({type:"string",value:a})` (loop-char `r`, digit-test var `s`) becomes 2.1.202's `,!l)r.push({type:"string",value:a})` (loop-char `n`, digit-test var `i`) — the loop-char and receiver names swapped (`r`↔`n`) and the digit-test helper renamed (`s`→`i`), while the flag (`l`) and accumulator (`a`) held. Both builds' Bun runtime banner (`Bun v1.4.0`/`Bun/1.4.0`) is identical, so this reads as a local recompile shifting the minifier's naming, not a runtime/bundler upgrade like 2.1.181's — and the structural anchor, which matches the `type:"string"` AST tag rather than identifier names, was built for exactly this case. Build provenance: factory size grew 231,708,784 → 243,631,376 bytes (+11.4 MB, the largest single-version jump in this ledger) and the parser site drifted 207,862,449 → 215,221,436 (+7,358,987 bytes). A strings diff (5,819 added / 5,251 removed, also the largest yet) lines up with Anthropic's own 2.1.202 changelog: a new `/config` "Dynamic workflow size" setting, `workflow.run_id`/`workflow.name` OpenTelemetry attributes, and a `/workflows` layout pass — corroborated by added strings like `CORRECTNESS_ANGLES`, `finder_budget`, bundled "Managed Agents" reference docs, and a Storybook-source converter. One official line, "Fixed workflow scripts with unicode quote escapes in strings being corrupted before parsing," is worth naming so it isn't mistaken for a VH1-adjacent fix: that's an acorn-style JS source parser (`ecmaVersion:"latest",sourceType:"module"`, present unchanged in both builds, just shifted) validating user-authored workflow scripts — a different parser at a different layer than the character-level JSON tokenizer this repo patches. The ~122 charCode/codePoint/tokenizer-flavored hits in the strings diff trace to that same pre-existing library code shifting position under the rebuild, not new tokenizer logic. This is the **fifteenth** effective upstream release since 2.1.181 (after 2.1.183, 185, 186, 187, 190, 191, 193, 195, 196, 197, 198, 199, 200, 201) to leave VH1 unfixed. The version-agnostic patcher re-applied with no script change (`!l`→`!0`, one byte; factory `7414f707861e…` → patched `a13d8253c64a…`), verified on disk (bug 0 / fix 1), by a valid ad-hoc signature, and by this very session's mmap'd inode (patched dogfooding). One disk-level footnote: the patched file is 1,417,536 bytes smaller than the factory original — not the content patch itself (a same-length 1-byte flip) but the re-sign: Apple's Developer ID CodeDirectory (1,888,837 bytes, 59,015+7 hash slots, plus a 9,047-byte certificate-chain signature) is replaced by a smaller ad-hoc one (472,288 bytes, 14,754+2 slots, no certificate blob), accounting for essentially all of it — a known, mechanical consequence of ad-hoc re-signing, not a content change.

## 2026-07-04

### Changed

- Bumped the tested badge to **2.1.201**, folding in two upstream releases at once — Claude Code updated 2.1.199 → 2.1.200 (the 2.1.200 bump landed overnight and was verified but not separately recorded) → 2.1.201. Both transitions leave VH1 unpatched upstream: the ±260-byte window around the parser site is byte-for-byte identical across 2.1.199, 2.1.200 and 2.1.201 — still `,!l)n.push({type:"string",value:a})`, no normalization needed — the ninth and tenth raw-frozen builds in a row (unbroken since 2.1.187). The structural anchor finds exactly one vulnerable site in each factory binary (bug 1 / fix 0), and the `e[++t]` character-scan loop signature appears the same 7 times in all three. Build provenance: 2.1.199 → 2.1.200 shrank 446,752 bytes (232,155,536 → 231,708,784) with the site drifting 799,552 bytes (207,062,833 → 207,862,385); 2.1.200 → 2.1.201 is the unusual case — both factory binaries are *exactly* 231,708,784 bytes, yet they are **not** byte-identical (first difference at offset 2112, a Mach-O load-command address field) and the parser site still drifted 64 bytes (207,862,385 → 207,862,449), confirming a genuinely new build that merely repacked to the same size. A strings diff over 2.1.200 → 2.1.201 shows 158 short strings added and 160 removed, with zero touching the character-level string tokenizer (no `charCode`/`codePoint`/`tokenizer` additions) — the added set is dominated by gateway/session/feature-flag surface (`allowedHttpHookUrls`, `disableRemoteControl`, `disableClaudeAiConnectors`, `/workflows`, Sessions-API labels), none reaching the parser. These are the **thirteenth and fourteenth** effective upstream releases since 2.1.181 (after 2.1.183, 185, 186, 187, 190, 191, 193, 195, 196, 197, 198, 199) to leave VH1 unfixed. The version-agnostic patcher re-applied to 2.1.201 with no script change (`!l`→`!0`, one byte; factory `a0852d76…` → patched `a9941c6f…`), verified on disk (bug 0 / fix 1) with a valid ad-hoc signature and by the running session's mmap'd inode (PIDs 45409/50688 both hold inode 57281235 — patched dogfooding).

## 2026-07-03

### Changed

- Documented the model-side boundary across README and the investigation doc, and posted a [second community comment on #62123](https://github.com/anthropics/claude-code/issues/62123#issuecomment-4878159880) contributing two weeks of forensics data: the stray-token pattern before leaked `<invoke>` XML (`câ`/`call`/`court`/`count` — all c-initial, all in the opener position, across CLI/Desktop and Chinese/Japanese/Korean-heavy sessions), and a confabulation shape verified the same day in which the model imagined tool runs inside a single thinking block and issued false "prompt injection" / "environment corrupted" alerts — every claim failing the claim-vs-artifact transcript check (related to the #64409 cluster). A new Technical Limitations entry makes the scope explicit: model-side shapes are upstream of any client fix; what the repo offers there is triage (fingerprinting which shape you're hitting), not defense.
- Bumped the tested badge to **2.1.199**. Claude Code updated 2.1.198 → 2.1.199 (consecutive). A two-way binary diff confirms VH1 remains unpatched upstream: the ±260-byte window around the parser site is byte-for-byte identical to 2.1.198 — still `,!l)n.push({type:"string",value:a})`, no normalization needed, the eighth raw-frozen build in a row (unbroken since 2.1.187). The structural anchor still finds exactly one vulnerable site in the whole binary (bug 1 / fix 0), and the character-scan loop signature `e[++t]` appears the same 7 times in both binaries. The factory binary grew 2.83 MB (229,328,464 → 232,155,536) and the site drifted 1,326,226 bytes (205,736,607 → 207,062,833), confirming a genuinely new build with the parser frozen in place. A strings diff puts all 4,031 added (and 2,708 removed) short strings elsewhere — roughly 1,400 are bundler-generated class-constructor guards (`Cannot call a class constructor _XX without |new|`, a toolchain-level change), and the rest is dominated by CSS design tokens (violet/magenta/neutral palettes, `--hl-*` highlight theme, Anthropic Sans/Mono) for a UI template layer — with zero new tokenizer strings and a single generic `parse` hit (`parseRepoSlug`), none touching the character-level string tokenizer. This is the **twelfth** effective upstream release since 2.1.181 (after 2.1.183, 185, 186, 187, 190, 191, 193, 195, 196, 197, 198) to leave VH1 unfixed. The version-agnostic patcher re-applied with no script change (`!l`→`!0`, one byte; original `e3cb61ab…` → patched `c154554c…`), verified on disk (bug 0 / fix 1), by signature, and by the running session's mmap'd inode (this very session, launched 21 seconds after the patch completed — patched dogfooding).

## 2026-07-02

### Fixed

- **Hook: counter arithmetic broke on a counter file with no entry for the current session+tool.** `grep -c` prints `0` AND exits 1 on no match, so the old `|| echo 0` stacked a second zero onto the count (`0\n0`), producing shell `syntax error` noise in the block message and defeating the 3-strike CRITICAL escalation. Observed live on 2026-06-30 (the message read "Blocked calls in this session: 0\n0"). The count is now taken from `grep` alone with a numeric-format guard, and a regression test covers the dirty-counter-file case the old suite never exercised (it always started from a deleted counter file).

### Changed

- **Hook: MCP `{}` is now judged by per-session history instead of blocked unconditionally.** The only real-world firing of the old blanket rule was a false positive: a legitimately zero-argument MCP call (`tabs_context_mcp`, whose schema is all-optional) was blocked, and the model was told the arguments would "be empty again" and to `/clear` a healthy session. Hooks can't read MCP schemas, so a bare `{}` carries no signal by itself — but the VH1 poisoning signature does: a tool that sent real arguments earlier in the session, then collapsed to `{}`. The hook now records non-empty MCP calls per session (`~/.claude/state/evap-shield-nonempty`) and blocks `{}` only for a tool with that history; a first `{}` passes and is logged as `allowed`. The block message now leads with the history evidence, drops the unconditional "known bug" framing, and gains an escape hatch for intentionally-empty calls. Log lines gain an `action` field (`blocked`/`allowed`). Hook test suite: 25 → 30 tests (history-gate three-state, cross-session isolation, dirty counter, log actions).

- Bumped the tested badge to **2.1.198**. Claude Code updated 2.1.197 → 2.1.198 (consecutive). A two-way binary diff confirms VH1 remains unpatched upstream: the ±260-byte window around the parser site is byte-for-byte identical to 2.1.197 — still `,!l)n.push({type:"string",value:a})`, no normalization needed, the seventh raw-frozen build in a row (after 187→191, 191→193, 193→195, 195→196, 196→197, and now 197→198) and unbroken since 2.1.187. The structural anchor still finds exactly one vulnerable site in the whole binary (bug 1 / fix 0), and the character-scan loop signature `e[++t]` appears the same 7 times in both binaries. The factory binary grew 2.08 MB (227,251,472 → 229,328,464) and the site drifted 3,048,115 bytes (202,688,492 → 205,736,607), confirming a genuinely new build with the parser frozen in place. A strings diff puts all 15,452 added (and 3,719 removed) short strings elsewhere — the bulk traces to this release's two headline additions, a highlight.js 11 syntax-highlighting upgrade (large per-language keyword dictionaries) and the new `/dataviz` skill (color-palette validator, chart-design copy) — with zero new tokenizer strings and 31 generic `parse` hits (argparse, YAML, Storybook, proxy responses), none touching the character-level string tokenizer. This is the **eleventh** effective upstream release since 2.1.181 (after 2.1.183, 185, 186, 187, 190, 191, 193, 195, 196, 197) to leave VH1 unfixed. The version-agnostic patcher re-applied with no script change (`!l`→`!0`, one byte; original `ab6f7ee1…` → patched `5b923d8e…`), verified on disk (bug 0 / fix 1), by signature, by the running session's mmap'd inode (this very session, launched 19 seconds after the patch completed — patched dogfooding), and by launch timing.

## 2026-07-01

### Changed

- Bumped the tested badge to **2.1.197**. Claude Code updated 2.1.196 → 2.1.197 (consecutive). A two-way binary diff confirms VH1 remains unpatched upstream: the ±120-byte window around the parser site is byte-for-byte identical to 2.1.196 — still `,!l)n.push({type:"string",value:a})`, no normalization needed, the sixth raw-frozen build in a row (after 187→191, 191→193, 193→195, 195→196, and now 196→197) and unbroken since 2.1.187. The structural anchor still finds exactly one vulnerable site in the whole binary (bug 1 / fix 0). The factory binary grew 1.4 MB (225,782,608 → 227,251,472) and the site drifted 100,324 bytes (202,588,168 → 202,688,492), confirming a genuinely new build with the parser frozen in place. A strings diff puts all 3,526 added (and 3,368 removed) short strings elsewhere — tool/agent/context/task/model/MCP/auth subsystems — with tokenizer (+22) and parser (+64) counts minimal and none touching the character-level string tokenizer. This is the **tenth** effective upstream release since 2.1.181 (after 2.1.183, 185, 186, 187, 190, 191, 193, 195, 196) to leave VH1 unfixed. The version-agnostic patcher re-applied with no script change (`!l`→`!0`, one byte; original `8cc0c4d1…` → patched `e94ede6d…`), verified on disk (bug 0 / fix 1), by signature, by the running session's mmap'd inode (this very session — patched dogfooding), and by launch timing.

## 2026-06-30

### Changed

- Bumped the tested badge to **2.1.196**. Claude Code updated 2.1.195 → 2.1.196 (consecutive). A two-way binary diff confirms VH1 remains unpatched upstream: the ±120-byte window around the parser site is byte-for-byte identical to 2.1.195 — still `,!l)n.push({type:"string",value:a})`, no normalization needed, the fifth raw-frozen build in a row (after 187→191, 191→193, 193→195, and now 195→196) and unbroken since 2.1.187. The structural anchor still finds exactly one vulnerable site in the whole binary (bug 1 / fix 0). The factory binary grew 1.1 MB (224,682,640 → 225,782,608) and the site drifted 981,275 bytes (201,606,893 → 202,588,168), confirming a genuinely new build with the parser frozen in place. A strings diff puts all 10,262 added (and 7,616 removed) short strings elsewhere — agent/plugin/MCP/skill/workflow/sandbox/OAuth/Bedrock subsystems — none touching the character-level string tokenizer. This is the **ninth** effective upstream release since 2.1.181 (after 2.1.183, 185, 186, 187, 190, 191, 193, 195) to leave VH1 unfixed. The version-agnostic patcher re-applied with no script change (`!l`→`!0`, one byte; original `6fc6e61a…` → patched `7fed84d2…`), verified on disk (bug 0 / fix 1), by signature, by the running session's mmap'd inode (this very session — patched dogfooding), and by launch timing.

## 2026-06-27

### Changed

- Bumped the tested badge to **2.1.195**. Claude Code updated 2.1.193 → 2.1.195 (2.1.194 skipped). A two-way binary diff confirms VH1 remains unpatched upstream: the ±120-byte window around the parser site is byte-for-byte identical to 2.1.193 — still `,!l)n.push({type:"string",value:a})`, no normalization needed, the third raw-frozen build in a row (after 187→191 and 191→193) and unbroken since 2.1.187 — and even the preceding escape-scan loop (`if(r==="\\"){…l=!0;break}a+=r+e[t]`) is untouched. The structural anchor still finds exactly one vulnerable site in the whole binary (bug 1 / fix 0). The factory binary grew 2.43 MB (222,248,240 → 224,682,640) and the site drifted 3,313,810 bytes (198,293,083 → 201,606,893), confirming a genuinely new build with the parser frozen in place. A strings diff puts all 4,746 added (and 2,534 removed) short strings elsewhere — an LLM gateway/proxy relay layer (re-emitting Anthropic-shaped `text/event-stream`, Bedrock's AWS binary event-stream, stripping the client's `Authorization`), a JWE/JWK/OAuth credential layer, the agent/workflow subsystem, voice streaming, sandboxing, and a Storybook adapter — none touching the character-level string tokenizer. This is the **eighth** effective upstream release since 2.1.181 (after 2.1.183, 185, 186, 187, 190, 191, 193) to leave VH1 unfixed. The version-agnostic patcher re-applied with no script change (`!l`→`!0`, one byte; original `8b45adad…` → patched `84c24c42…`), verified on disk (bug 0 / fix 1), by signature, by the running session's mmap'd inode (this very session — patched dogfooding), and by launch timing.

## 2026-06-26

### Changed

- Bumped the tested badge to **2.1.193**, catching up from 2.1.187 — the 2.1.191 re-check below (2026-06-25) was recorded in the investigation ledger but the public badge wasn't bumped at the time, so this entry covers both 2.1.191 and 2.1.193. Claude Code updated 2.1.191 → 2.1.193 (2.1.192 skipped). A two-way binary diff confirms VH1 remains unpatched upstream: the ±120-byte window around the parser site is byte-for-byte identical to 2.1.191 — still `,!l)n.push({type:"string",value:a})`, no normalization needed, continuing the raw-frozen streak since 2.1.187 — and the structural anchor still finds exactly one vulnerable site in the whole binary (bug 1 / fix 0). The factory binary grew another 2.39 MB (219,856,224 → 222,248,240) and the site drifted 989,822 bytes (197,303,261 → 198,293,083), confirming a genuinely new build. A strings diff puts all 3,701 new short strings elsewhere — Bun runtime stream builtins (`@putByIdDirectPrivate(readableStreamController…)`, an HTTP "Parse Error" path), a workflow-VM sandbox (`attacker-reachable` clone walker), and a feedback-report UI template — none touching the character-level string tokenizer. This is the **seventh** effective upstream release since 2.1.181 (after 2.1.183, 185, 186, 187, 190, 191) to leave VH1 unfixed. The version-agnostic patcher re-applied with no script change (`!l`→`!0`, one byte; original `f7513a30…` → patched `cadbe992…`), verified on disk (bug 0 / fix 1), by signature, by the running session's mmap'd inode (this very session — patched dogfooding), and by launch timing.

## 2026-06-25

### Changed

- Re-checked 2.1.190 and 2.1.191. After 2.1.187, Claude Code shipped 2.1.190 (2026-06-24; 188/189 skipped) and 2.1.191. Both are genuinely new builds (factory size 215,994,048 → 217,273,568 → 219,856,224; parser site drifted to 197,303,261 in 191) and both leave the site frozen at `,!l)n.push({type:"string",value:a})`, raw-identical to 2.1.187. A strings diff attributes the growth to a Bun runtime upgrade (HTTP agent/proxy/tunnel, async_hooks) and the workflow/agent subsystem; 2.1.191's eighteen changelog entries (/rewind, background agents, sandboxing, MCP retry, a 37% CPU cut) touch none of the tool-call parser. 2.1.190 was a brief ~8-hour unpatched window — never patched before 191 superseded it — and 191 was re-patched and verified by byte, inode, and launch timing. These are the **fifth** and **sixth** effective upstream releases since 2.1.181 to leave VH1 unfixed. (The public badge bump for these was folded into the 2026-06-26 entry.)

## 2026-06-24

### Changed

- Bumped the tested badge to **2.1.187**. Claude Code updated 2.1.186 → 2.1.187 (consecutive again — the second back-to-back bump after 2.1.185→2.1.186). A two-way binary diff confirms VH1 remains unpatched upstream: the ±260-byte window around the parser site is byte-for-byte identical to 2.1.186 — still `,!l)n.push({type:"string",value:a})`, names unshuffled, identical without even needing normalization — and the structural anchor still finds exactly one vulnerable site in the whole binary (bug 1 / fix 0). Unlike the +858 KB 2.1.186 build, 2.1.187 *shrank*: original size 216811232 → 215994048 (−817,184 bytes), while the site still drifted 193217884 → 193618676 (+400,792), confirming a genuinely new build rather than a recompile-free copy. A strings diff shows 2.1.187 is a real build (not a frozen reissue), but its 39 added / 26 removed human-readable messages all land elsewhere: `/toggle-memory` renamed to `/pause-memory`, Fable 5 usage-credit copy normalized (dropping "for a limited time" / "Included in your plan limits"), sandbox/credential-protection fields, GitHub Actions setup, and MCP idle-timeout — none of it touching the JSON parser. This is the **fourth** effective upstream release since 2.1.181 (after 2.1.183, 2.1.185, and 2.1.186) to leave VH1 unfixed. The version-agnostic patcher re-applied with no script change (`!l`→`!0`, one byte; original `a59a16ba…` → patched `df0eb868…`), verified on disk (bug 0 / fix 1), by signature, and against the running session's mmap'd patched binary.
- Pre-disclosure documentation pass. Fixed the broken `{owner}` placeholder in both READMEs' clone URL (→ `tznthou`, which previously failed on copy-paste). Refreshed the #62123 stats (54 → 57 comments; "zero staff response" re-verified against the issue's commenter associations as of 2026-06-24 — all 57 are non-staff). Extended the investigation's §7 version ledger to cover 2.1.185–187 and folded in the external #70196 live case (takepan, 2.1.186, later marked `duplicate` / `area:model`). Marked FIX-PLAN.md as a decision-history snapshot frozen at 2026-06-16, with current analysis pointed to the investigation. Corrected the update-detector test count in both READMEs (18 → 21).

## 2026-06-23

### Changed

- Bumped the tested badge to **2.1.186**. Claude Code updated 2.1.185 → 2.1.186 (consecutive this time — no skipped version, unlike 2.1.182/2.1.184). A two-way binary diff confirms VH1 remains unpatched upstream: the ~280-byte window around the parser site is byte-for-byte identical to 2.1.185 — still `,!l)n.push({type:"string",value:a})`, names unshuffled — and the structural anchor still finds exactly one vulnerable site in the whole binary. Unlike the frozen-size 2.1.183→2.1.185 reissues, 2.1.186 is a *substantial* new build: original size grew 215952608 → 216811232 (+858,624 bytes) and the site drifted 192250818 → 193217884 (+967,066). A strings diff attributes the growth to sandbox / egress agent-proxy / managed-agents (subagent) / MCP resource tools / plugin governance — none of it touching the JSON parser. This is the **third** effective upstream release since 2.1.181 (after 2.1.183 and 2.1.185) to leave VH1 unfixed, and the strongest signal yet: upstream shipped ~858 KB of real new code and still didn't touch the parser. The version-agnostic patcher re-applied with no script change (`!l`→`!0`, one byte; original `463a79cc…` → patched `8b277719…`), verified on disk (bug 0 / fix 1) and at launch (2.1.186).

## 2026-06-22

### Changed

- Bumped the tested badge to **2.1.185**. After Claude Code updated 2.1.183 → 2.1.185 (2.1.184 was skipped, as 2.1.182 was before it), a two-way binary diff confirms VH1 remains unpatched upstream: the parser site is byte-for-byte identical to 2.1.183 — still `,!l)n.push({type:"string",value:a})`, names unshuffled (Bun 1.4 carried over) — though it has drifted 64 bytes within the file (192250754 → 192250818), confirming a genuinely new build with the parser site frozen rather than a recompile-free copy. Original size is unchanged (215952608) and 2.1.185's new strings are all sandbox / agent-proxy / cloud-sessions / oauth / MCP governance, none touching the JSON parser. This is the **second** effective upstream release since 2.1.181 (after 2.1.183) to leave VH1 unfixed. The version-agnostic patcher re-applied with no script change (`!l`→`!0`, one byte; original `a280c23b…` → patched `69862459…`), re-verified on disk, in the recorded state, and against the running session's mmap'd binary.

## 2026-06-20

### Changed

- `docs/vh1-investigation.md`: flagged that the MCP-tool hook coverage rests on validation *ordering* and was verified only on 2.1.179 — not re-checked on 181/183 like the parser site; and documented that this re-check is now automated by the `SessionStart` hook (a stat-only fingerprint fast path gates the anchored scan).

## 2026-06-19

### Added

- **SessionStart update-detection hook** (`check-update.sh`): fingerprints the live binary on each session start (stat-only fast path, silent when unchanged) and, when Claude Code was updated — which overwrites the binary patch — reports whether the VH1 patch needs re-applying (`vulnerable` → re-run the patcher; `unknown` → possibly fixed upstream, verify; `patched`/unchanged → quiet). Detection and reporting only: it never patches and never edits files. Standalone single file, fail-open, covered by `test-check-update.sh` (21 tests).

### Changed

- `install.sh` now installs both hooks (PreToolUse + SessionStart) with the same idempotent, non-destructive settings merge; the installer suite expanded to 26 tests.
- Bumped the tested badge to **2.1.183**. After Claude Code updated 2.1.181 → 2.1.183 (2.1.182 was skipped), a three-way binary diff confirms the upstream parser is byte-for-byte identical to 2.1.181 once identifiers are normalized — this time the minifier didn't even reshuffle names (still `l/n/a`) — so VH1 remains unpatched upstream. None of 2.1.183's sixteen changelog entries touch tool-call parsing. The version-agnostic patcher re-applied with no script change (`!l`→`!0`, one byte).

## 2026-06-18

### Added

- VH1 bug investigation writeup (`docs/vh1-investigation.md`), including a 2.1.181 re-check that confirms the bug remains unpatched upstream.

### Changed

- The VH1 patcher is now **version-agnostic**: a structural anchor on the parser's invariant replaces the hardcoded minified variable pattern, so it survives bundler/minifier reshuffles across Claude Code versions — verified across the 2.1.181 Bun 1.4 identifier rename.
- README (EN/ZH): documented the version-agnostic patcher — the 1-byte structural patch (previously described as a 2-byte literal), the 45-test patcher suite, and the 2.1.181 Bun 1.4 note.

## 2026-06-17

### Added

- Patcher failure-path regression suite (`test-patch-vh1.sh`) and installer merge-safety suite (`test-install.sh`).

### Changed

- Reframed the hook's scope in the docs: the patch is the root fix; the hook closes the MCP-tool gap that Claude Code's built-in validation leaves open.

### Fixed

- The hook handles malformed input and a missing `jq` gracefully (fail-open) instead of crashing.
- Restore is now atomic via `rename()`, with hardened patch-state handling.

### Security

- Restore verifies the backup's SHA-256 before replacing the binary.

## 2026-06-16

### Added

- Initial release: a PreToolUse hook (`evap-shield.sh`) and a binary patch (`patch-vh1.sh`) for the Claude Code VH1 streaming parser bug, with a one-command installer (`install.sh`).

### Fixed

- Prevent a macOS brick when patching: the patched Mach-O is ad-hoc re-signed and launch-checked on an isolated temporary inode, so patching never overwrites the running binary's inode (which AMFI would SIGKILL on relaunch).
