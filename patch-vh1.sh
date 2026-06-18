#!/bin/bash
# patch-vh1.sh — Patch Claude Code VH1 streaming parser bug
#
# Flips the negated gate flag to `!0` in the VH1 string tokenizer to prevent
# silent string token drops that cascade into empty tool arguments. The match is
# structural (not tied to minified variable names), so it survives bundler /
# minifier reshuffles across Claude Code versions — e.g. the Bun 1.4 upgrade in
# 2.1.181 renamed the whole identifier space and broke the old literal match.
#
# Usage: bash patch-vh1.sh [--dry-run] [--restore] [--status]
#
# The patch flips one byte (same length) so it doesn't shift any offsets.
# A per-hash backup is created before each patch.
#
# See: https://github.com/anthropics/claude-code/issues/62123
#      https://github.com/anthropics/claude-code/issues/67765

set -euo pipefail

DRY_RUN=false
RESTORE=false
STATUS=false
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --restore) RESTORE=true ;;
    --status) STATUS=true ;;
    *) echo "Unknown option: $arg" >&2; exit 1 ;;
  esac
done

STATE_DIR="${EVAP_SHIELD_STATE_DIR:-$HOME/.claude/state}"
STATE_FILE="$STATE_DIR/patch-vh1.json"
BACKUP_DIR="$STATE_DIR/patch-backups"

# ── Locate Claude Code binary ──
find_claude_binary() {
  if [[ -L "$HOME/.local/bin/claude" ]]; then
    readlink "$HOME/.local/bin/claude" 2>/dev/null && return
  fi
  if [[ -f "$HOME/.local/bin/claude" ]]; then
    echo "$HOME/.local/bin/claude" && return
  fi
  local bin
  bin=$(type -P claude 2>/dev/null || true)
  if [[ -n "$bin" ]]; then
    if [[ -L "$bin" ]]; then readlink "$bin" 2>/dev/null && return; fi
    echo "$bin" && return
  fi
  local npm_bin="/usr/local/lib/node_modules/@anthropic-ai/claude-code/cli.js"
  if [[ -f "$npm_bin" ]]; then echo "$npm_bin" && return; fi
  echo ""
}

CLI_BIN=$(find_claude_binary)
if [[ -z "$CLI_BIN" || ! -f "$CLI_BIN" ]]; then
  echo "Error: Could not find Claude Code binary." >&2
  exit 1
fi

CLI_VERSION=$(strings "$CLI_BIN" | grep -o '"2\.[0-9]*\.[0-9]*"' | tail -1 | tr -d '"' || echo "unknown")
[[ -z "$CLI_VERSION" ]] && CLI_VERSION="unknown"

CLI_SHA256=$(shasum -a 256 "$CLI_BIN" | cut -d' ' -f1)
CLI_SIZE=$(wc -c < "$CLI_BIN" | tr -d ' ')

# ── macOS Mach-O signing ──
is_macos_macho() {
  [[ "$(uname -s 2>/dev/null || true)" == "Darwin" ]] || return 1
  command -v file >/dev/null 2>&1 || return 1
  file "$CLI_BIN" 2>/dev/null | grep -q "Mach-O"
}

codesign_status() {
  if is_macos_macho && command -v codesign >/dev/null 2>&1; then
    if codesign --verify --verbose=1 "$CLI_BIN" >/dev/null 2>&1; then
      echo "valid"
    else
      echo "invalid"
    fi
  else
    echo "n/a"
  fi
}

resign_macho_if_needed() {
  is_macos_macho || return 0

  if ! command -v codesign >/dev/null 2>&1; then
    echo "Error: patched macOS Mach-O binary requires codesign, but codesign was not found." >&2
    return 1
  fi

  if codesign --verify --verbose=1 "$CLI_BIN" >/dev/null 2>&1; then
    echo "Mach-O signature already valid."
    return 0
  fi

  if $DRY_RUN; then
    echo "[dry-run] Would re-sign Mach-O binary (ad-hoc)."
    return 0
  fi

  echo "Re-signing Mach-O binary (ad-hoc)..."
  codesign --force --sign - "$CLI_BIN" >/dev/null
}

smoke_test_cli() {
  # Verify the patched binary launches — but exec a COPY on a fresh inode,
  # never "$CLI_BIN" directly. If Claude Code is currently running it holds
  # CLI_BIN's inode mmap'd; an in-place patch makes the on-disk pages diverge
  # from that live image, and macOS AMFI SIGKILLs any new exec of that inode
  # (exit 137) — a false negative that would trigger a needless restore. A
  # copy on a new inode tests the patched bytes cleanly (an ad-hoc signature
  # travels with the bytes, so the copy is equally valid to launch).
  # Stage the probe NEXT TO CLI_BIN, not in TMPDIR: a noexec or policy-blocked
  # TMPDIR would fail the launch check on a perfectly good binary and trigger a
  # needless restore. CLI_BIN's own directory is writable (we patch there) and
  # executable. It's still a separate inode, so it avoids the running-inode kill.
  local probe version_out rc=0
  probe=$(mktemp "${CLI_BIN%/*}/claude-smoke.XXXXXX") || {
    echo "Error: smoke test could not create a temp file." >&2
    return 1
  }
  if ! cp "$CLI_BIN" "$probe"; then
    rm -f "$probe"
    echo "Error: smoke test could not copy the binary for launch check." >&2
    return 1
  fi
  if ! chmod +x "$probe"; then
    rm -f "$probe"
    echo "Error: smoke test could not set the execute bit on the probe." >&2
    return 1
  fi
  # `... && rc=0 || rc=$?` keeps the failing exit out of `set -e`'s reach
  # (a bare `version_out=$(...)` would abort here on a non-zero exit).
  version_out=$("$probe" --version 2>&1) && rc=0 || rc=$?
  rm -f "$probe"

  if [[ $rc -eq 0 ]]; then
    echo "Launch check: $version_out"
    return 0
  fi

  echo "Error: patched binary failed launch check (exit $rc)." >&2
  if [[ -n "$version_out" ]]; then
    echo "$version_out" >&2
  fi
  return 1
}

# Verify-then-atomic-restore: check the backup's hash against the expected
# original SHA ($1), then stage it to a random sibling temp and rename() over
# CLI_BIN. The hash check stops a corrupted/substituted backup from silently
# replacing the live binary. rename() is atomic and yields a fresh inode, so a
# crash mid-copy can't truncate CLI_BIN, and we never overwrite the inode a
# running Claude Code still holds (which would risk an AMFI kill on relaunch).
restore_from_backup() {
  local expected_sha="${1:-}"
  if [[ ! -f "$BACKUP_PATH" ]]; then
    echo "Error: backup not found, cannot restore: $BACKUP_PATH" >&2
    return 1
  fi
  local actual_sha
  actual_sha=$(shasum -a 256 "$BACKUP_PATH" | cut -d' ' -f1)
  if [[ -n "$expected_sha" && "$actual_sha" != "$expected_sha" ]]; then
    echo "Error: backup hash mismatch (expected $expected_sha, got $actual_sha)." >&2
    echo "Refusing to restore a backup that doesn't match recorded state." >&2
    return 1
  fi
  # Random (not PID-predictable) temp name avoids a name-race in the binary's
  # dir; mktemp creates it 0600, so restore the 755 exec mode before rename.
  local tmp
  tmp=$(mktemp "${CLI_BIN}.evap-restore.XXXXXX") || {
    echo "Error: could not create restore temp file." >&2
    return 1
  }
  if ! cp "$BACKUP_PATH" "$tmp"; then
    rm -f "$tmp"
    echo "Error: failed to stage restore copy." >&2
    return 1
  fi
  chmod 755 "$tmp"
  mv -f "$tmp" "$CLI_BIN"
}

# Abort path for a failed patch step: print the given reason, restore the
# original binary from backup, and exit 1. Only ever called once we've already
# decided to bail, so the unconditional exit is intentional. The `if` around
# restore_from_backup keeps its non-zero return out of `set -e`'s reach.
abort_and_restore() {
  echo ""
  echo "WARNING: $1 Restoring..."
  if restore_from_backup "$CLI_SHA256"; then
    echo "Restored. Binary unchanged."
  else
    echo "Restore FAILED — original backup at $BACKUP_PATH" >&2
  fi
  exit 1
}

# ── Pattern detection ──
# Version-agnostic: don't hardcode minified variable names — they get reshuffled
# whenever the bundler/minifier changes (the Bun 1.4 upgrade in 2.1.181 renamed
# the whole identifier space, breaking a literal ',!Y)q.push' match). Anchor on
# the structural invariant that survives minification:
#   ,!<flag>)<recv>.push({type:"string",value:<acc>})
# `type:"string"` is a data literal (an AST node tag), not an identifier, so the
# minifier never touches it. <flag> is the single-char local whose negation
# gates the push; we flip !<flag> -> !0 to always keep the (possibly partial)
# string token. <flag> must be an identifier char or `0` ([A-Za-z_$0]); digits
# 1-9 are excluded because !1/!2 are minified `false` literals, not variables —
# matching them could mis-flag and mis-patch an unrelated site. <recv>/<acc> are
# matched loosely (locate only, never rewritten).
# The `})` right after value:<acc> separates the VH1 string push from the
# children.push({type:"string",value:X,offset:...}) node, which carries more keys.
detect_pattern() {
  python3 - "$CLI_BIN" <<'PY'
import re, sys
data = open(sys.argv[1], 'rb').read()
PAT = re.compile(
    rb',!([A-Za-z_$0])\)'                # ,!<flag>)  identifier char or 0; never 1-9
    rb'(?:[A-Za-z_$][A-Za-z_$0-9]*)'     # <recv>     push receiver (locate only)
    rb'\.push\(\{type:"string",value:'   # .push({type:"string",value:
    rb'(?:[A-Za-z_$][A-Za-z_$0-9]*)\}\)' # <acc>})    value then immediate close
)
vuln = patched = 0
for m in PAT.finditer(data):
    if m.group(1) == b'0':
        patched += 1
    else:
        vuln += 1
print(f'{vuln} {patched}')
PY
}

SEARCH_RESULT=$(detect_pattern)
BUG_COUNT=$(echo "$SEARCH_RESULT" | cut -d' ' -f1)
FIX_COUNT=$(echo "$SEARCH_RESULT" | cut -d' ' -f2)

if [[ "$BUG_COUNT" -gt 0 ]]; then
  PATCH_STATUS="vulnerable"
elif [[ "$FIX_COUNT" -gt 0 ]]; then
  PATCH_STATUS="patched"
else
  PATCH_STATUS="unknown"
fi

# ── Status mode ──
if $STATUS; then
  echo "Binary:  $CLI_BIN"
  echo "Version: $CLI_VERSION"
  echo "SHA256:  $CLI_SHA256"
  echo "Size:    $CLI_SIZE"
  echo "Status:  $PATCH_STATUS"
  SIGN_STATUS=$(codesign_status)
  if [[ "$SIGN_STATUS" != "n/a" ]]; then
    echo "Signature: $SIGN_STATUS"
  fi
  if [[ -f "$STATE_FILE" ]]; then
    LAST_VERSION=$(python3 - "$STATE_FILE" <<'PY' 2>/dev/null || echo "?"
import json, sys
print(json.load(open(sys.argv[1])).get('version','?'))
PY
)
    LAST_SHA=$(python3 - "$STATE_FILE" <<'PY' 2>/dev/null || echo "?"
import json, sys
print(json.load(open(sys.argv[1])).get('patched_sha256','?'))
PY
)
    echo "Last patched: v$LAST_VERSION (sha256: ${LAST_SHA:0:12}...)"
  fi
  if [[ "$PATCH_STATUS" == "vulnerable" ]]; then
    echo ""
    echo "Run: bash $0"
  fi
  exit 0
fi

echo "VH1 Streaming Parser Patch"
echo "=========================="
echo ""
echo "Binary:  $CLI_BIN"
echo "Version: $CLI_VERSION"
echo "SHA256:  ${CLI_SHA256:0:16}..."
echo "Status:  $PATCH_STATUS"
echo ""

# ── Restore mode ──
if $RESTORE; then
  if [[ ! -f "$STATE_FILE" ]]; then
    echo "Error: No patch state found at $STATE_FILE" >&2
    exit 1
  fi

  RESTORE_INFO=$(python3 - "$STATE_FILE" <<'PY'
import json, sys
s = json.load(open(sys.argv[1]))
print(s.get('original_sha256',''))
print(s.get('patched_sha256',''))
print(s.get('backup_path',''))
PY
)
  ORIG_SHA=$(echo "$RESTORE_INFO" | sed -n '1p')
  PATCHED_SHA=$(echo "$RESTORE_INFO" | sed -n '2p')
  BACKUP_PATH=$(echo "$RESTORE_INFO" | sed -n '3p')

  if [[ -z "$BACKUP_PATH" || ! -f "$BACKUP_PATH" ]]; then
    echo "Error: Backup file not found: $BACKUP_PATH" >&2
    exit 1
  fi

  if [[ "$CLI_SHA256" != "$PATCHED_SHA" ]]; then
    echo "Error: Current binary doesn't match the patched version." >&2
    echo "  Current:  $CLI_SHA256" >&2
    echo "  Expected: $PATCHED_SHA" >&2
    echo "Binary may have been updated. Restore is not safe." >&2
    exit 1
  fi

  if $DRY_RUN; then
    echo "[dry-run] Would restore from $BACKUP_PATH"
  elif restore_from_backup "$ORIG_SHA"; then
    rm -f "$STATE_FILE"
    echo "Restored from backup. Patch state cleared."
  else
    echo "Error: restore failed — original backup at $BACKUP_PATH" >&2
    exit 1
  fi
  exit 0
fi

# ── Patch mode ──
if [[ "$PATCH_STATUS" == "patched" ]]; then
  echo "Already patched."
  # If the binary no longer matches our recorded patch (e.g. Claude Code was
  # updated to a version that happens to look patched), don't mutate it or
  # refresh state — a stale backup/SHA pairing could later make --restore
  # overwrite the wrong binary. Warn and leave recorded state untouched.
  if [[ -f "$STATE_FILE" ]]; then
    RECORDED_SHA=$(python3 - "$STATE_FILE" <<'PY' 2>/dev/null || echo ""
import json, sys
print(json.load(open(sys.argv[1])).get('patched_sha256',''))
PY
)
    if [[ -n "$RECORDED_SHA" && "$CLI_SHA256" != "$RECORDED_SHA" ]]; then
      echo "Warning: binary SHA differs from recorded patch state — Claude Code may have been updated." >&2
      echo "If so, run 'bash $0 --restore' then re-patch." >&2
    fi
  fi
  if ! resign_macho_if_needed; then
    echo "Error: re-signing the already-patched binary failed." >&2
    exit 1
  fi
  if $DRY_RUN; then
    exit 0
  fi
  if ! smoke_test_cli; then
    echo "Error: already-patched binary failed launch check." >&2
    exit 1
  fi
  exit 0
fi

if [[ "$PATCH_STATUS" == "unknown" ]]; then
  echo "Error: VH1 bug pattern not found in this binary." >&2
  echo "This version may use a different parser, or Anthropic may have fixed it." >&2
  exit 1
fi

if [[ "$BUG_COUNT" -gt 1 ]]; then
  echo "Error: Found $BUG_COUNT occurrences (expected 1). Refusing to patch." >&2
  exit 1
fi

echo "Found bug pattern: 1 occurrence"
echo "Patch: !<flag> → !0 (1 byte, same length)"
echo ""

if $DRY_RUN; then
  echo "[dry-run] Would patch $CLI_BIN"
  exit 0
fi

# ── Backup (per-hash) ──
mkdir -p "$BACKUP_DIR"
BACKUP_PATH="$BACKUP_DIR/${CLI_SHA256:0:12}.bin"

if [[ ! -f "$BACKUP_PATH" ]]; then
  cp -p "$CLI_BIN" "$BACKUP_PATH"
  echo "Backup: $BACKUP_PATH"
else
  echo "Backup exists for this hash (kept)"
fi

# ── Patch ──
# Same structural regex as detect_pattern(): find the one vulnerable
# ,!<flag>)...push({type:"string",value:...}) site and flip the single flag byte
# to '0'. Editing exactly one byte (not replacing a string) guarantees the file
# length is unchanged, so no Mach-O offsets shift.
python3 - "$CLI_BIN" <<'PY'
import re, sys
path = sys.argv[1]
data = open(path, 'rb').read()
PAT = re.compile(
    rb',!([A-Za-z_$0])\)'                # flag: identifier char or 0, never 1-9 (see detect_pattern)
    rb'(?:[A-Za-z_$][A-Za-z_$0-9]*)'
    rb'\.push\(\{type:"string",value:'
    rb'(?:[A-Za-z_$][A-Za-z_$0-9]*)\}\)'
)
vuln = [m for m in PAT.finditer(data) if m.group(1) != b'0']
assert len(vuln) == 1, f'Expected 1 vulnerable site, found {len(vuln)}'
m = vuln[0]
flag = m.group(1).decode()
pos = m.start(1)               # offset of the single flag byte
assert m.end(1) - pos == 1, 'flag is not a single byte'
patched = data[:pos] + b'0' + data[pos+1:]
assert len(patched) == len(data), 'File size changed'
open(path, 'wb').write(patched)
print(f'Patch applied: !{flag} -> !0 at offset {pos}.')
PY

BYTE_PATCH_SIZE=$(wc -c < "$CLI_BIN" | tr -d ' ')
# resign is a bare call under `set -e`: a non-zero return would abort the
# script here, leaving a patched-but-unsigned (un-launchable) binary that
# never reaches the smoke-test/restore safety net below. Guard it so any
# re-sign failure restores the original binary instead of bricking it.
if ! resign_macho_if_needed; then
  abort_and_restore "Re-signing failed."
fi

# ── Verify + save state ──
PATCHED_SHA256=$(shasum -a 256 "$CLI_BIN" | cut -d' ' -f1)
VERIFY_RESULT=$(detect_pattern)
V_BUG=$(echo "$VERIFY_RESULT" | cut -d' ' -f1)
V_FIX=$(echo "$VERIFY_RESULT" | cut -d' ' -f2)
PATCHED_SIZE=$(wc -c < "$CLI_BIN" | tr -d ' ')

echo ""
echo "Verification:"
echo "  Bug pattern: $V_BUG (expect 0)"
echo "  Fix pattern: $V_FIX (expect 1)"
echo "  Byte patch size: $CLI_SIZE → $BYTE_PATCH_SIZE"
echo "  Final size:      $PATCHED_SIZE (differs after re-sign; not size-gated)"

if [[ "$V_BUG" -eq 0 && "$V_FIX" -eq 1 && "$CLI_SIZE" -eq "$BYTE_PATCH_SIZE" ]]; then
  if ! smoke_test_cli; then
    abort_and_restore "Launch verification failed."
  fi

  mkdir -p "$STATE_DIR"
  PATCHED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  python3 - "$STATE_FILE" "$CLI_BIN" "$CLI_VERSION" "$CLI_SHA256" "$PATCHED_SHA256" "$CLI_SIZE" "$PATCHED_SIZE" "$BACKUP_PATH" "$PATCHED_AT" <<'PY'
import json, sys
(_, state_file, binary, version, orig_sha, patched_sha,
 orig_size, size, backup_path, patched_at) = sys.argv
state = {
    'schema': 1,
    'binary': binary,
    'version': version,
    'original_sha256': orig_sha,
    'patched_sha256': patched_sha,
    'original_size': int(orig_size),
    'size': int(size),
    'backup_path': backup_path,
    'patched_at': patched_at,
}
json.dump(state, open(state_file, 'w'), indent=2)
PY
  echo ""
  echo "Patch verified. State saved to $STATE_FILE"
  echo "Restart Claude Code for the fix to take effect."
  echo ""
  echo "After 'claude update': bash $0"
  echo "To restore:            bash $0 --restore"
  echo "Check status:          bash $0 --status"
else
  abort_and_restore "Verification failed."
fi
