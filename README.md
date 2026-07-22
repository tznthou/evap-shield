# evap-shield

[![MIT License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Bash](https://img.shields.io/badge/Bash-4.0+-4EAA25.svg)](https://www.gnu.org/software/bash/)
[![Claude Code](https://img.shields.io/badge/Claude_Code-2.1.x-7C3AED.svg)](https://docs.anthropic.com/en/docs/claude-code)
[![Tested](https://img.shields.io/badge/tested-2.1.217-brightgreen.svg)](CHANGELOG.md)

[中文](README_ZH.md)

Defense toolkit for the Claude Code VH1 streaming parser bug that silently turns tool arguments into `{}`.

---

## Before You Use This

evap-shield ships two independent layers with different risk profiles. Read this before choosing which to run.

**The hook is low-risk.** `install.sh` installs a PreToolUse hook that only *detects* and blocks `{}` calls to MCP tools. It never touches the Claude Code binary, and uninstalling is deleting one file and one settings entry.

**The binary patch is the root fix — and an unofficial modification of a signed binary.** `patch-vh1.sh` edits the Claude Code CLI binary on disk to flip one parser flag. On macOS it then ad-hoc re-signs the binary, replacing the factory Developer ID signature with a local one — there's no Anthropic key to re-sign with, so this is the only way a locally-patched Mach-O will launch. It runs, but it is no longer the binary Anthropic shipped.

**Its effectiveness is unit-verified, not end-to-end verified.** A white-box unit test runs the original and patched parser side by side across 760 streaming-truncation cases with 0 regressions; the rest is structural inference. There is no end-to-end confirmation, for a concrete reason: the affected parser's primary failure path is structurally unreachable from a server-side mock — only the real interactive TUI's abort-and-finalize handler commits the mid-stream buffer that triggers it, so the fix cannot be exercised end to end in a controlled harness. The unit test is the strongest verification available, and this is exactly how far it reaches.

**Terms of Service is yours to check.** Modifying a vendor's signed binary *may* have implications under Anthropic's Terms of Service. We have not assessed the terms and make no claim either way — if that matters to you, read them and decide for yourself before patching.

**At your own risk, and fully reversible.** This is defensive research on software installed on your own machine, not an invitation to modify binaries casually. There's a per-hash backup, automatic rollback on any failed step, and a one-command restore (see [Undoing the Patch](#undoing-the-patch)) — but the binary is on your machine, and the call is yours.

### Which layer should you run?

| If you... | Run | What you get |
|-----------|-----|--------------|
| Want to stay conservative — don't want to touch the binary, or care about ToS | **Hook only**: `bash install.sh` | Detection and blocking of MCP `{}`, without modifying anything Anthropic shipped |
| Want to fix the parser at its source and accept the risk of modifying a signed binary | **Add the patch**: `bash patch-vh1.sh` | `{}` stopped at the source for every tool, via the unofficial binary modification above |

This is a *risk* question — which layer you're comfortable running. It's separate from [Rollback Criteria](#rollback-criteria) below, which is a *symptom* question — when the bug is active enough to be worth patching.

---

## What's the Bug?

Claude Code's streaming JSON parser has a flaw in its string tokenizer (function `VH1` in the minified bundle). When a JSON string value is split across streaming chunks, the parser silently drops the entire token. This cascades through three more parser layers until `JSON.parse("{}")` succeeds — and every subsequent call to that tool in the same session sends empty arguments.

Your AI can think. It just can't act. And it doesn't know why.

Tracked in [#62123](https://github.com/anthropics/claude-code/issues/62123) (62 comments, zero staff response as of 2026-07-12) and root-caused in [#67765](https://github.com/anthropics/claude-code/issues/67765).

**Affected**: Opus 4.7, Opus 4.8, Sonnet 4.5. **Not affected**: Opus 4.6, Sonnet 4.6.

---

## How evap-shield Works

Two independent layers, either works alone:

| Layer | What it does | Survives `claude update`? |
|-------|-------------|---------------------------|
| **Patch** (`patch-vh1.sh`) | Flips the negated gate flag to `!0` in the VH1 tokenizer (1 byte, same length). The match is structural — anchored on the parser's invariant, not minified variable names — so it survives bundler reshuffles across versions (e.g. the Bun 1.4 rename in 2.1.181). Partial strings get pushed instead of dropped, so `{}` never forms at the source — for every tool. | No — re-run after each update |
| **Hook** (`evap-shield.sh`) | PreToolUse hook that blocks `{}` calls to **MCP tools** — the one gap Claude Code's built-in validation doesn't cover (see [Design Decisions](#design-decisions)). Judged by per-session history: `{}` is blocked only for a tool that already sent non-empty arguments in the same session (the VH1 poisoning signature); a first `{}` passes, because legitimately zero-argument MCP tools exist. Logs both, so you can tell whether the bug is firing. | Yes |

The patch is the root fix — it stops `{}` from forming at all. The hook is the no-restart safety net for MCP tools, and your observability into whether the bug is live.

---

## Features

| Command | Description |
|---------|-------------|
| `bash install.sh` | One-command install into `~/.claude/` |
| `bash install.sh --dry-run` | Preview changes without modifying anything |
| `bash patch-vh1.sh` | Find and patch the VH1 bug in the CLI binary |
| `bash patch-vh1.sh --status` | Check binary version, patch status, last patch info |
| `bash patch-vh1.sh --restore` | Restore the original binary from per-hash backup |
| `bash patch-vh1.sh --dry-run` | Preview patch without applying |
| `bash check-update.sh` | Report VH1 patch status when Claude Code was updated (the SessionStart hook runs this) |
| `bash test-evap-shield.sh` | Run the hook test suite (30 tests) |
| `bash test-patch-vh1.sh` | Run the patcher failure-path suite (45 tests) |
| `bash test-install.sh` | Run the installer merge-safety suite (26 tests) |
| `bash test-check-update.sh` | Run the update-detector suite (21 tests) |

---

## Quick Start

### Prerequisites

- Bash 4.0+
- `jq` (for the hook)
- Python 3 (for the patcher)
- `codesign` on macOS (used to re-sign patched Mach-O binaries)

### Install the hook

```bash
git clone https://github.com/tznthou/evap-shield.git
cd evap-shield
bash install.sh
```

This copies `evap-shield.sh` (PreToolUse) and `check-update.sh` (SessionStart) to `~/.claude/hooks/` and registers both in `settings.json`. A timestamped backup of your settings is created first, and the merge is idempotent — re-running only adds what's missing.

### Apply the binary patch (optional)

```bash
bash patch-vh1.sh
```

The script automatically locates your Claude Code binary, verifies the bug pattern exists exactly once, creates a per-hash backup, patches, re-signs patched Mach-O binaries on macOS, and verifies the result with a launch check.

> **Tip:** For the cleanest result, fully quit Claude Code before patching. The script is still safe to run while it's open — the launch check uses an isolated temporary copy, not the running binary, so it isn't tripped up by the in-memory image.

The patch takes effect only after a full restart, and must be re-run after every `claude update` — see [Keeping the Patch Effective](#keeping-the-patch-effective).

---

## Keeping the Patch Effective

The patch edits the binary on disk — but that's not the whole story. Here's when it actually takes effect, and when you have to re-run it.

### After patching: restart required

The running Claude Code already loaded the old, unpatched binary into memory, so **the patch does not affect your current session**. To activate it:

1. Fully quit Claude Code — not just `/clear` or a new session, the whole process.
2. If you launch Claude Code through a wrapper or persistent launcher (a terminal multiplexer, a background daemon, an IDE extension host), that process may hold its own copy of the binary — restart the wrapper too.
3. Start a fresh session and confirm with `bash patch-vh1.sh --status` (expect `Status: patched`).

### After `claude update`: re-run required

`claude update` installs a brand-new version into a separate directory and repoints `claude` at it. Your patched binary is left behind — untouched but no longer used — and the new one ships with the bug again.

So after every update:

```bash
bash patch-vh1.sh        # re-detect, back up, and patch the new version
# then restart, as above
```

`--status` reflects the on-disk binary the script resolves, not the one your current session is running. Run `bash patch-vh1.sh --status` any time to see whether it's `patched` or `vulnerable`.

### Automatic update detection

`install.sh` also registers a **SessionStart hook** (`check-update.sh`) that fingerprints the binary on each start. The common case — nothing changed — is silent and near-instant (a stat-only fast path; no hashing, no scan). Only when Claude Code was actually updated, which overwrites the patch, does it speak up:

- **vulnerable** — the update wiped the patch; it tells you to re-run `patch-vh1.sh`.
- **unknown** — the VH1 pattern is gone; the parser may have been restructured (possibly fixed upstream), so it asks you to verify.
- **patched / unchanged** — stays quiet.

It only detects and reports — it never patches the binary and never edits any file. The judgement, and the binary modification itself, stay in your hands.

---

## Undoing the Patch

The patch is fully reversible, and reverting is designed to never leave you worse off than an unpatched binary.

```bash
bash patch-vh1.sh --restore
```

This restores the original binary from the per-hash backup and clears the patch state. Three layers cover the rollback:

| Layer | When | What it does |
|-------|------|--------------|
| **Auto-restore** | A patch step fails (re-sign, launch check, or verification) | Restores the original and exits before a half-patched binary is ever left in place |
| **`--restore`** | Any time after patching | Reverts to the backed-up original, hash-checked first |
| **Manual** | If you don't even trust the script | `cp` the backup from `~/.claude/state/patch-backups/` over the binary yourself |

What makes the rollback safe:

- **Atomic.** Restore stages a copy and then `rename()`s it over the binary, so an interrupted restore can't truncate it. The fresh inode also leaves a still-running Claude Code untouched.
- **Verified.** The backup's SHA-256 is checked against the recorded original *before* it replaces anything — a corrupted backup is refused, not installed.
- **The floor is "it runs".** Worst case you land on an unpatched-but-working binary (the bug is back, but Claude Code launches) — never one that won't start.
- **No working Claude Code required.** `--restore` is a terminal command, so even if a launch ever fails, you can recover without a functioning Claude Code.

Like the patch itself, a restore takes effect on the next full restart.

---

## Project Structure

```
evap-shield/
  evap-shield.sh        # PreToolUse hook — blocks {} to MCP tools
  check-update.sh       # SessionStart hook — reports if an update wiped the patch
  install.sh            # One-command installer for both hooks
  patch-vh1.sh          # Binary patch automation (locate → backup → patch → verify)
  test-evap-shield.sh   # Hook test suite (30 tests)
  test-patch-vh1.sh     # Patcher failure-path tests (45 tests)
  test-install.sh       # Installer merge-safety tests (26 tests)
  test-check-update.sh  # Update-detector tests (21 tests)
  FIX-PLAN.md           # Full technical analysis and rollback criteria
  README.md             # English
  README_ZH.md          # Chinese
  CHANGELOG.md          # Changelog (English)
  CHANGELOG_ZH.md       # Changelog (Chinese)
  docs/vh1-investigation.md  # Full VH1 bug investigation
```

---

## Rollback Criteria

If you're returning to an affected model (Opus 4.8) after using 4.6:

| Signal | Action |
|--------|--------|
| Zero `{}` events in 5 sessions | Stay on 4.8 |
| Hook catches `{}` but blocks all | Keep observing |
| Hook fires 3+ times in one session | Apply the binary patch |
| `/clear` doesn't recover the session | Fall back to Opus 4.6 |

See [FIX-PLAN.md](FIX-PLAN.md) for the full decision tree.

---

## Why This Exists

On May 23, 2026, Claude Code started freezing. Not crashing — freezing. The model would think, decide what to do, then... nothing. The tool call evaporated. Twenty-one minutes of staring at a spinner before realizing something was fundamentally broken.

Three days of investigation traced it to a single boolean in a minified JavaScript tokenizer: `Y=!0` sets a flag when a JSON string is split mid-stream, and `!Y` silently skips pushing that token. One dropped string cascades into `{}` arguments, which get cached per-tool, poisoning the entire session.

The issue has 57 comments and zero official response. The only clean escape was downgrading to Opus 4.6.

We built evap-shield because waiting wasn't an option.

## Design Decisions

**A PreToolUse hook, scoped to the MCP gap.** We considered MCP-server middleware (schema-aware rejection of `{}`) and chose a PreToolUse hook, which receives the full `tool_input` payload. Its effective scope is the MCP surface: a `{}` to a built-in tool (Read, Edit, Bash) is rejected by Claude Code's own validation, which runs *before* PreToolUse hooks, so the hook never sees it. The hook fires only for **MCP tools**, whose validation runs *after* it. Built-in tools are covered by Claude Code itself; the hook closes the MCP gap and logs `{}` events so you know the bug is live.

**A session-history gate, not a blanket `{}` block.** A hook can't read MCP schemas, and legitimately zero-argument MCP tools exist — a blanket "block every MCP `{}`" mistakes their normal calls for the bug (observed live on 2026-06-30: a legal zero-argument context call was blocked and the model was told to `/clear` a healthy session). So the hook keys on the bug's actual signature instead: VH1 poisoning is per-tool and sticky — a tool sends real arguments, then collapses to `{}` and stays empty. The hook records, per session, which tools have sent non-empty arguments; a `{}` blocks only for a tool with that history. A first `{}` passes (and is logged as `allowed`), which trades the first evaporated call — usually a harmless server-side validation error — for near-zero false positives. Since a poisoned tool stays empty, the second call and every one after is still caught.

**Two layers, not one.** The patch fixes the parser at the source — every tool — but gets wiped on each update. The hook survives updates and needs no restart, but only covers the MCP gap. So the patch is the root fix, and the hook is the permanent net for the window when the patch isn't active (after an update, before you re-run it). Either works alone.

**Per-hash backups, not per-version.** `--restore` must only restore the exact binary that was patched. If the user runs `claude update` between patch and restore, the backup is from a different version. Matching on SHA-256 prevents silent corruption — and the restore itself verifies the backup's hash before trusting it, then swaps it in atomically with `rename()` so an interrupted rollback can never leave a truncated binary.

**Redacted logs by default.** The hook logs tool name and argument key names — never argument values. File paths, code content, and user data stay out of the log file. Full input logging is a privacy risk for an open-source tool.

---

## Technical Limitations

- **The hook does not protect built-in tools.** A `{}` to Read, Edit, Bash, etc. is rejected by Claude Code's own validation *before* the PreToolUse hook runs, so the hook never sees it. The required-field map lists built-ins for completeness, but in practice the hook only ever fires for **MCP tools** (`mcp__*`), whose validation runs after it. Built-in `{}` is handled by Claude Code itself, not by this hook.
- **The hook lets the first `{}` through.** The session-history gate blocks a `{}` only for a tool that already sent non-empty arguments in the same session. A tool whose *first* call in a session evaporates is passed through to the MCP server (typically a server-side validation error, and it is logged as `allowed`) — the price of not blocking legitimately zero-argument tools, whose `{}` is indistinguishable from the bug without history. A tool that takes arguments *sometimes* (optional-only schemas) can still be blocked on an intentional `{}` after a non-empty call; the block message tells the model how to signal that.
- **The patch's root-fix effect is unit-verified, not end-to-end.** 760/0 streaming-boundary unit cases confirm partial tokens are pushed instead of dropped; full end-to-end confirmation isn't observable through a server mock (the affected parser path is structurally unreachable from the outside). It's unit-proof plus structural inference.
- The binary patch anchors on a structural invariant in the parser, not minified variable names, so it survives bundler/minifier reshuffles across versions (verified across the 2.1.181 Bun 1.4 rename). If Anthropic restructures the parser itself, the patcher refuses to patch rather than corrupt it (safe failure, not silent corruption).
- The patch does not survive `claude update`. Re-run `patch-vh1.sh` after each update — the SessionStart hook (`check-update.sh`) detects the update and reminds you, but the re-patch itself stays manual by design.
- The hook cannot prevent the model from retrying in a loop before the hook fires. The error message is written as a terminal instruction to stop the model, but this depends on model compliance.
- **Model-side failure shapes are out of scope — for the patch, the hook, and any client-side tool.** The antml-prefix-dropped family (tool calls leaking as `<invoke>` XML text with a stray c-initial token — `câ`/`call`/`court`/`count`) and confabulation (fabricated tool results, imagined tool runs, and false "prompt injection detected" / "environment corrupted" alerts) originate in the model's generation layer, upstream of anything a client can patch. What this repo offers there is triage, not defense: fingerprint which shape you're hitting (empty `{}` args vs. leaked XML vs. claims that don't match the transcript) so you know whether to patch, retry, restart the session, or re-verify the model's claimed work. See the [2026-07-03 forensics comment in #62123](https://github.com/anthropics/claude-code/issues/62123#issuecomment-4878159880), and [§8 of the investigation report](docs/vh1-investigation.md#8-honest-scope-one-corner-of-the-cluster) for a quantified 2026-07-12 survey showing that side of the cluster accelerating.

---

## License

[MIT](LICENSE)

---

## Author

**tznthou** — [tznthou@gmail.com](mailto:tznthou@gmail.com)
