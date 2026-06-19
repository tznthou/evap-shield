#!/bin/bash
# test-check-update.sh — tests for check-update.sh (the update-detection hook)
#
# Like test-patch-vh1.sh, this uses a FAKE shell-script "binary" under a
# throwaway $HOME, so it never touches a production binary, never calls
# codesign, and is fast/CI-safe. The fake carries (or omits) the VH1 byte
# pattern so patch-vh1.sh --status classifies it vulnerable/patched/unknown,
# and prints a version string so version parsing works.
#
# Run: bash test-check-update.sh

set -uo pipefail

CHECK="$(cd "$(dirname "$0")" && pwd)/check-update.sh"
PASS=0
FAIL=0
ROOT=$(mktemp -d "/tmp/test-check-update.XXXXXX")
trap 'rm -rf "$ROOT"' EXIT

HOME_DIR="$ROOT/home"
STATE_DIR="$ROOT/state"
mkdir -p "$HOME_DIR/.local/bin" "$HOME_DIR/versions" "$STATE_DIR"

VULN_BODY=',!l)n.push({type:"string",value:a})'
FIX_BODY=',!0)n.push({type:"string",value:a})'

ok()  { echo "  PASS: $1"; PASS=$((PASS + 1)); }
bad() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

# Stage a fake binary for version $1 with body $2, point the symlink at it.
set_binary() {
  local ver="$1" body="$2" path="$HOME_DIR/versions/$1"
  {
    echo "#!/bin/bash"
    echo "# fake claude \"$ver\""
    echo "# VH1: $body"
    echo "echo \"$ver (Claude Code)\""
  } > "$path"
  chmod +x "$path"
  ln -sf "$path" "$HOME_DIR/.local/bin/claude"
}

# Manually plant a "seen" state with an arbitrary old fingerprint + version,
# to simulate "we ran before, then Claude Code changed".
write_seen() {
  printf '{"fingerprint":"%s","version":"%s","sha256":"old","status":"%s","checked_at":"old"}\n' \
    "$1" "$2" "${3:-vulnerable}" > "$STATE_DIR/evap-shield-seen.json"
}

clear_seen() { rm -f "$STATE_DIR/evap-shield-seen.json"; }

run() {
  HOME="$HOME_DIR" \
  EVAP_SHIELD_STATE_DIR="$STATE_DIR" \
    bash "$CHECK" "$@" 2>/dev/null
}

echo "test-check-update.sh"
echo "===================="

# ── 1. First run + vulnerable -> warns, records seen ──
clear_seen
set_binary "2.1.183" "$VULN_BODY"
OUT=$(run)
echo "$OUT" | grep -q "NOT patched" && ok "first run + vulnerable warns" || bad "first run + vulnerable warns (got: $OUT)"
[[ -f "$STATE_DIR/evap-shield-seen.json" ]] && ok "seen file written" || bad "seen file written"
SEEN_VER=$(jq -r '.version' "$STATE_DIR/evap-shield-seen.json" 2>/dev/null)
[[ "$SEEN_VER" == "2.1.183" ]] && ok "seen records version" || bad "seen records version (got: $SEEN_VER)"

# ── 2. Unchanged -> silent fast path ──
OUT=$(run)
[[ -z "$OUT" ]] && ok "unchanged is silent" || bad "unchanged is silent (got: $OUT)"

# ── 3. Update (symlink -> new version) + vulnerable -> 'overwritten' ──
set_binary "2.1.185" "$VULN_BODY"
OUT=$(run)
echo "$OUT" | grep -q "overwritten" && ok "update+vulnerable says overwritten" || bad "update+vulnerable says overwritten (got: $OUT)"
echo "$OUT" | grep -q "2.1.183 -> 2.1.185" && ok "update shows old -> new" || bad "update shows old -> new (got: $OUT)"

# ── 4. Update + patched -> silent in plain mode (info, non-first) ──
write_seen "stale-fp" "2.1.185" "vulnerable"
set_binary "2.1.187" "$FIX_BODY"
OUT=$(run)
[[ -z "$OUT" ]] && ok "update+patched is silent (plain)" || bad "update+patched silent (got: $OUT)"

# ── 5. Update + unknown (no VH1 pattern) -> 'pattern not found' ──
write_seen "stale-fp2" "2.1.187" "patched"
set_binary "2.1.190" "no vh1 pattern here"
OUT=$(run)
echo "$OUT" | grep -q "pattern not found" && ok "update+unknown warns pattern not found" || bad "update+unknown warns (got: $OUT)"
echo "$OUT" | grep -q "Verify" && ok "unknown suggests verify" || bad "unknown suggests verify (got: $OUT)"

# ── 6. --json + vulnerable -> valid JSON with systemMessage ──
write_seen "stale-fp3" "2.1.190" "unknown"
set_binary "2.1.191" "$VULN_BODY"
OUT=$(run --json)
echo "$OUT" | jq empty 2>/dev/null && ok "json output is valid JSON" || bad "json valid (got: $OUT)"
HEN=$(echo "$OUT" | jq -r '.hookSpecificOutput.hookEventName' 2>/dev/null)
[[ "$HEN" == "SessionStart" ]] && ok "json hookEventName=SessionStart" || bad "json hookEventName (got: $HEN)"
SYS=$(echo "$OUT" | jq -r '.hookSpecificOutput.systemMessage // ""' 2>/dev/null)
echo "$SYS" | grep -q "patch-vh1.sh" && ok "json systemMessage has action" || bad "json systemMessage (got: $SYS)"

# ── 7. --json + patched -> valid JSON, suppressOutput, no systemMessage ──
write_seen "stale-fp4" "2.1.191" "vulnerable"
set_binary "2.1.192" "$FIX_BODY"
OUT=$(run --json)
echo "$OUT" | jq empty 2>/dev/null && ok "json patched is valid JSON" || bad "json patched valid (got: $OUT)"
SUP=$(echo "$OUT" | jq -r '.hookSpecificOutput.suppressOutput // false' 2>/dev/null)
[[ "$SUP" == "true" ]] && ok "json patched suppressOutput=true" || bad "json patched suppressOutput (got: $SUP)"
SYS=$(echo "$OUT" | jq -r '.hookSpecificOutput.systemMessage // ""' 2>/dev/null)
[[ -z "$SYS" ]] && ok "json patched has no systemMessage" || bad "json patched no systemMessage (got: $SYS)"

# ── 8. --force + patched -> prints even though info ──
write_seen "stale-fp5" "2.1.192" "patched"
set_binary "2.1.192" "$FIX_BODY"
OUT=$(run --force)
echo "$OUT" | grep -q "patch is in place" && ok "--force prints patched confirmation" || bad "--force prints patched (got: $OUT)"

# ── 9. fail-open: no binary at all -> exit 0, no output ──
rm -f "$HOME_DIR/.local/bin/claude"
OUT=$(run; echo "rc=$?")
echo "$OUT" | grep -q "rc=0" && ok "no binary -> exit 0 (fail-open)" || bad "no binary fail-open (got: $OUT)"
LINES=$(run | wc -l | tr -d ' ')
[[ "$LINES" == "0" ]] && ok "no binary -> no output" || bad "no binary no output (got $LINES lines)"

echo ""
echo "===================="
echo "PASS: $PASS  FAIL: $FAIL"
[[ "$FAIL" -eq 0 ]] || exit 1
