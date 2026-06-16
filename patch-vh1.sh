#!/bin/bash
# patch-vh1.sh — Patch Claude Code VH1 streaming parser bug
#
# Replaces `!Y` with `!0` in the VH1 string tokenizer to prevent
# silent string token drops that cascade into empty tool arguments.
#
# Usage: bash patch-vh1.sh [--dry-run] [--restore] [--status]
#
# The patch is same-length (2 bytes) so it doesn't shift any offsets.
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

# ── Pattern detection ──
detect_pattern() {
  python3 -c "
data = open('$CLI_BIN', 'rb').read()
bug = b',!Y)q.push({type:\"string\"'
fix = b',!0)q.push({type:\"string\"'
print(f'{data.count(bug)} {data.count(fix)}')
"
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
  if [[ -f "$STATE_FILE" ]]; then
    LAST_VERSION=$(python3 -c "import json; print(json.load(open('$STATE_FILE')).get('version','?'))" 2>/dev/null || echo "?")
    LAST_SHA=$(python3 -c "import json; print(json.load(open('$STATE_FILE')).get('patched_sha256','?'))" 2>/dev/null || echo "?")
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

  RESTORE_INFO=$(python3 -c "
import json
s = json.load(open('$STATE_FILE'))
print(s.get('original_sha256',''))
print(s.get('patched_sha256',''))
print(s.get('backup_path',''))
")
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
  else
    cp "$BACKUP_PATH" "$CLI_BIN"
    rm -f "$STATE_FILE"
    echo "Restored from backup. Patch state cleared."
  fi
  exit 0
fi

# ── Patch mode ──
if [[ "$PATCH_STATUS" == "patched" ]]; then
  echo "Already patched."
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
echo "Patch: !Y → !0 (2 bytes, same length)"
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
python3 -c "
data = open('$CLI_BIN', 'rb').read()
bug = b',!Y)q.push({type:\"string\"'
fix = b',!0)q.push({type:\"string\"'

assert data.count(bug) == 1, f'Expected 1 occurrence, found {data.count(bug)}'
assert len(bug) == len(fix), 'Pattern length mismatch'

patched = data.replace(bug, fix, 1)
assert len(patched) == len(data), 'File size changed'
assert patched.count(fix) == 1
assert patched.count(bug) == 0

open('$CLI_BIN', 'wb').write(patched)
print('Patch applied.')
"

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
echo "  Size:        $CLI_SIZE → $PATCHED_SIZE"

if [[ "$V_BUG" -eq 0 && "$V_FIX" -eq 1 && "$CLI_SIZE" -eq "$PATCHED_SIZE" ]]; then
  mkdir -p "$STATE_DIR"
  python3 -c "
import json
state = {
    'schema': 1,
    'binary': '$CLI_BIN',
    'version': '$CLI_VERSION',
    'original_sha256': '$CLI_SHA256',
    'patched_sha256': '$PATCHED_SHA256',
    'size': $CLI_SIZE,
    'backup_path': '$BACKUP_PATH',
    'patched_at': '$(date -u +%Y-%m-%dT%H:%M:%SZ)',
}
json.dump(state, open('$STATE_FILE', 'w'), indent=2)
"
  echo ""
  echo "Patch verified. State saved to $STATE_FILE"
  echo "Restart Claude Code for the fix to take effect."
  echo ""
  echo "After 'claude update': bash $0"
  echo "To restore:            bash $0 --restore"
  echo "Check status:          bash $0 --status"
else
  echo ""
  echo "WARNING: Verification failed. Restoring..."
  cp "$BACKUP_PATH" "$CLI_BIN"
  echo "Restored. Binary unchanged."
  exit 1
fi
