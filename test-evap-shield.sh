#!/bin/bash
# Test suite for evap-shield.sh
# Run: bash test-evap-shield.sh

set -euo pipefail

HOOK="$(dirname "$0")/evap-shield.sh"
PASS=0
FAIL=0
export EVAP_SHIELD_STATE_DIR="/tmp/evap-shield-test-state-$$"
COUNTER_FILE="$EVAP_SHIELD_STATE_DIR/evap-shield-counter"
export EVAP_SHIELD_LOG_DIR="/tmp/evap-shield-test-$$"
mkdir -p "$EVAP_SHIELD_LOG_DIR"

cleanup() {
  rm -rf "$EVAP_SHIELD_LOG_DIR" "$EVAP_SHIELD_STATE_DIR"
}
mkdir -p "$EVAP_SHIELD_STATE_DIR"
trap cleanup EXIT

assert_pass() {
  local desc="$1"
  local payload="$2"
  rm -f "$COUNTER_FILE"
  if printf '%s' "$payload" | bash "$HOOK" >/dev/null 2>/dev/null; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc (expected pass, got block)"
    FAIL=$((FAIL + 1))
  fi
}

assert_block() {
  local desc="$1"
  local payload="$2"
  rm -f "$COUNTER_FILE"
  local stderr_out
  if stderr_out=$(printf '%s' "$payload" | bash "$HOOK" 2>&1 >/dev/null); then
    echo "  FAIL: $desc (expected block, got pass)"
    FAIL=$((FAIL + 1))
  else
    if echo "$stderr_out" | grep -q "STREAMING PARSER BUG"; then
      echo "  PASS: $desc"
      PASS=$((PASS + 1))
    else
      echo "  FAIL: $desc (blocked but wrong message)"
      FAIL=$((FAIL + 1))
    fi
  fi
}

echo "=== evap-shield.sh test suite ==="
echo ""
echo "── Normal tool calls (should PASS) ──"

assert_pass "Read with file_path" \
  '{"tool_name":"Read","tool_input":{"file_path":"/tmp/test.txt"},"session_id":"test-1"}'

assert_pass "Edit with all required fields" \
  '{"tool_name":"Edit","tool_input":{"file_path":"/tmp/test.txt","old_string":"a","new_string":"b"},"session_id":"test-1"}'

assert_pass "Write with all required fields" \
  '{"tool_name":"Write","tool_input":{"file_path":"/tmp/test.txt","content":"hello"},"session_id":"test-1"}'

assert_pass "Bash with command" \
  '{"tool_name":"Bash","tool_input":{"command":"ls"},"session_id":"test-1"}'

assert_pass "Unknown tool with empty args (not in checklist)" \
  '{"tool_name":"SomeOtherTool","tool_input":{},"session_id":"test-1"}'

assert_pass "MCP tool with args" \
  '{"tool_name":"mcp__ccrecall__recall_query","tool_input":{"query":"test","projectId":"p1"},"session_id":"test-1"}'

echo ""
echo "── Evaporated tool calls (should BLOCK) ──"

assert_block "Read with empty args" \
  '{"tool_name":"Read","tool_input":{},"session_id":"test-2"}'

assert_block "Edit with empty args" \
  '{"tool_name":"Edit","tool_input":{},"session_id":"test-2"}'

assert_block "Write with empty args" \
  '{"tool_name":"Write","tool_input":{},"session_id":"test-2"}'

assert_block "Bash with empty args" \
  '{"tool_name":"Bash","tool_input":{},"session_id":"test-2"}'

assert_block "Read with null file_path" \
  '{"tool_name":"Read","tool_input":{"file_path":null},"session_id":"test-2"}'

assert_block "MCP tool with empty args" \
  '{"tool_name":"mcp__ccrecall__recall_query","tool_input":{},"session_id":"test-2"}'

assert_block "Edit with partial args (missing old_string)" \
  '{"tool_name":"Edit","tool_input":{"file_path":"/tmp/test.txt"},"session_id":"test-2"}'

assert_block "Write with only file_path (missing content)" \
  '{"tool_name":"Write","tool_input":{"file_path":"/tmp/test.txt"},"session_id":"test-2"}'

assert_block "Write with only content (missing file_path)" \
  '{"tool_name":"Write","tool_input":{"content":"hello"},"session_id":"test-2"}'

assert_block "Write with null content" \
  '{"tool_name":"Write","tool_input":{"file_path":"/tmp/test.txt","content":null},"session_id":"test-2"}'

echo ""
echo "── Consecutive counter escalation ──"

rm -f "$COUNTER_FILE"
for i in 1 2 3; do
  stderr_out=$(printf '{"tool_name":"Read","tool_input":{},"session_id":"test-3"}' | bash "$HOOK" 2>&1 >/dev/null || true)
  if [[ $i -ge 3 ]]; then
    if echo "$stderr_out" | grep -q "CRITICAL"; then
      echo "  PASS: Hit $i escalates to CRITICAL"
      PASS=$((PASS + 1))
    else
      echo "  FAIL: Hit $i should be CRITICAL"
      FAIL=$((FAIL + 1))
    fi
  else
    if echo "$stderr_out" | grep -q "WARNING"; then
      echo "  PASS: Hit $i stays at WARNING"
      PASS=$((PASS + 1))
    else
      echo "  FAIL: Hit $i should be WARNING"
      FAIL=$((FAIL + 1))
    fi
  fi
done

echo ""
echo "── Log file ──"

LOG_COUNT=$(wc -l < "$EVAP_SHIELD_LOG_DIR/evap-shield.log.jsonl" 2>/dev/null || echo 0)
LOG_COUNT=$(echo "$LOG_COUNT" | tr -d ' ')
if [[ "$LOG_COUNT" -gt 0 ]]; then
  echo "  PASS: Log file has $LOG_COUNT entries"
  PASS=$((PASS + 1))
else
  echo "  FAIL: Log file is empty"
  FAIL=$((FAIL + 1))
fi

if grep -q '"input"' "$EVAP_SHIELD_LOG_DIR/evap-shield.log.jsonl" 2>/dev/null; then
  echo "  FAIL: Log contains raw 'input' field (should be redacted)"
  FAIL=$((FAIL + 1))
else
  echo "  PASS: Log is redacted (no raw input)"
  PASS=$((PASS + 1))
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
