# Changelog

[中文](CHANGELOG_ZH.md)

All notable changes to evap-shield are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). This project groups changes by date rather than semantic version — it's a script toolkit, not a registry-published package.

## 2026-06-24

### Changed

- Bumped the tested badge to **2.1.187**. Claude Code updated 2.1.186 → 2.1.187 (consecutive again — the second back-to-back bump after 2.1.185→2.1.186). A two-way binary diff confirms VH1 remains unpatched upstream: the ±260-byte window around the parser site is byte-for-byte identical to 2.1.186 — still `,!l)n.push({type:"string",value:a})`, names unshuffled, identical without even needing normalization — and the structural anchor still finds exactly one vulnerable site in the whole binary (bug 1 / fix 0). Unlike the +858 KB 2.1.186 build, 2.1.187 *shrank*: original size 216811232 → 215994048 (−817,184 bytes), while the site still drifted 193217884 → 193618676 (+400,792), confirming a genuinely new build rather than a recompile-free copy. A strings diff shows 2.1.187 is a real build (not a frozen reissue), but its 39 added / 26 removed human-readable messages all land elsewhere: `/toggle-memory` renamed to `/pause-memory`, Fable 5 usage-credit copy normalized (dropping "for a limited time" / "Included in your plan limits"), sandbox/credential-protection fields, GitHub Actions setup, and MCP idle-timeout — none of it touching the JSON parser. This is the **fourth** effective upstream release since 2.1.181 (after 2.1.183, 2.1.185, and 2.1.186) to leave VH1 unfixed. The version-agnostic patcher re-applied with no script change (`!l`→`!0`, one byte; original `a59a16ba…` → patched `df0eb868…`), verified on disk (bug 0 / fix 1), by signature, and against the running session's mmap'd patched binary.

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
