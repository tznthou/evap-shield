# evap-shield

[![MIT License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Bash](https://img.shields.io/badge/Bash-4.0+-4EAA25.svg)](https://www.gnu.org/software/bash/)
[![Claude Code](https://img.shields.io/badge/Claude_Code-2.1.x-7C3AED.svg)](https://docs.anthropic.com/en/docs/claude-code)

[中文](README_ZH.md)

Defense toolkit for the Claude Code VH1 streaming parser bug that silently turns tool arguments into `{}`.

---

## What's the Bug?

Claude Code's streaming JSON parser has a flaw in its string tokenizer (function `VH1` in the minified bundle). When a JSON string value is split across streaming chunks, the parser silently drops the entire token. This cascades through three more parser layers until `JSON.parse("{}")` succeeds — and every subsequent call to that tool in the same session sends empty arguments.

Your AI can think. It just can't act. And it doesn't know why.

Tracked in [#62123](https://github.com/anthropics/claude-code/issues/62123) (54+ comments, zero staff response as of 2026-06-16) and root-caused in [#67765](https://github.com/anthropics/claude-code/issues/67765).

**Affected**: Opus 4.7, Opus 4.8, Sonnet 4.5. **Not affected**: Opus 4.6, Sonnet 4.6.

---

## How evap-shield Works

Two independent layers, either works alone:

| Layer | What it does | Survives `claude update`? |
|-------|-------------|---------------------------|
| **Hook** (`evap-shield.sh`) | PreToolUse hook that inspects every tool call. Blocks execution if required arguments are missing. Warns the model to stop retrying. | Yes |
| **Patch** (`patch-vh1.sh`) | Replaces `!Y` with `!0` in the VH1 tokenizer (2 bytes, same length). Partial strings get pushed instead of dropped. | No — re-run after each update |

The hook is your safety net. The patch reduces how often the hook needs to fire.

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
| `bash test-evap-shield.sh` | Run the hook test suite (21 tests) |
| `bash test-patch-vh1.sh` | Run the patcher failure-path suite (33 tests) |

---

## Quick Start

### Prerequisites

- Bash 4.0+
- `jq` (for the hook)
- Python 3 (for the patcher)
- `codesign` on macOS (used to re-sign patched Mach-O binaries)

### Install the hook

```bash
git clone https://github.com/{owner}/evap-shield.git
cd evap-shield
bash install.sh
```

This copies `evap-shield.sh` to `~/.claude/hooks/` and registers it in `settings.json`. A timestamped backup of your settings is created first.

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
  evap-shield.sh        # PreToolUse hook — blocks {} tool calls
  install.sh            # One-command hook installer
  patch-vh1.sh          # Binary patch automation (locate → backup → patch → verify)
  test-evap-shield.sh   # Hook test suite (21 tests)
  test-patch-vh1.sh     # Patcher failure-path tests (33 tests)
  FIX-PLAN.md           # Full technical analysis and rollback criteria
  README.md             # English
  README_ZH.md          # Chinese
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

The issue has 54+ comments and zero official response. The only clean escape was downgrading to Opus 4.6.

We built evap-shield because waiting wasn't an option.

## Design Decisions

**Hook over MCP middleware.** Our first plan was to add validation to MCP servers (schema-aware rejection of `{}`). But that only protects custom MCP tools — built-in tools like Read, Edit, and Bash are unprotected. Then we discovered that PreToolUse hooks receive the full `tool_input` payload and can block execution with exit code 2. One hook covers everything.

**Two layers, not one.** The hook blocks damage but doesn't fix the parser. The patch fixes the parser but gets wiped on update. Together, the hook is the permanent safety net and the patch reduces noise. Either works alone.

**Per-hash backups, not per-version.** `--restore` must only restore the exact binary that was patched. If the user runs `claude update` between patch and restore, the backup is from a different version. Matching on SHA-256 prevents silent corruption — and the restore itself verifies the backup's hash before trusting it, then swaps it in atomically with `rename()` so an interrupted rollback can never leave a truncated binary.

**Redacted logs by default.** The hook logs tool name and argument key names — never argument values. File paths, code content, and user data stay out of the log file. Full input logging is a privacy risk for an open-source tool.

---

## Technical Limitations

- The hook only checks tools with a hardcoded required-field map (Read, Edit, Write, Bash, NotebookEdit, `mcp__*`). New built-in tools not in this map will pass through.
- The binary patch targets a specific byte pattern. If Anthropic restructures the parser, the patcher will refuse to patch (safe failure, not silent corruption).
- The patch does not survive `claude update`. Re-run `patch-vh1.sh` after each update.
- The hook cannot prevent the model from retrying in a loop before the hook fires. The error message is written as a terminal instruction to stop the model, but this depends on model compliance.

---

## License

[MIT](LICENSE)

---

## Author

**tznthou** — [tznthou@gmail.com](mailto:tznthou@gmail.com)
