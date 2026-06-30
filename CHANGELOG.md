# Changelog

[中文](CHANGELOG_ZH.md)

All notable changes to evap-shield are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). This project groups changes by date rather than semantic version — it's a script toolkit, not a registry-published package.

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
