#!/bin/bash
# evap-shield.sh — PreToolUse hook
# Detects and blocks tool calls with empty/missing required arguments,
# a symptom of the Claude Code VH1 streaming parser bug (#62123, #67765).
#
# Install: add to settings.json under hooks.PreToolUse with matcher ""
# See: https://github.com/anthropics/claude-code/issues/62123

set -euo pipefail

PAYLOAD=$(cat)

# jq is a hard dependency: if it's missing the shield can't inspect anything.
# Surface that loudly (visible non-zero exit) rather than letting the JSON
# guard below read "jq absent" as "malformed input" and fail open silently —
# that would disable the shield with no signal, its worst failure mode.
if ! command -v jq >/dev/null 2>&1; then
  echo "evap-shield: jq not found — shield INACTIVE, tool calls pass unchecked" >&2
  exit 1
fi

# Fail open on malformed input: the VH1 bug produces *valid* JSON with an
# empty tool_input, so a payload that isn't valid JSON is not this symptom.
# Pass through silently instead of letting jq emit a parse error and a
# non-zero exit (noise to the user, and a non-2 exit reads as a hook error).
if ! printf '%s' "$PAYLOAD" | jq empty >/dev/null 2>&1; then
  exit 0
fi

TOOL_NAME=$(printf '%s' "$PAYLOAD" | jq -r '.tool_name // ""')
TOOL_INPUT=$(printf '%s' "$PAYLOAD" | jq -c '.tool_input // {}')

# ── Required-field map for built-in tools ──
# If a tool is listed here and ANY of its required fields are missing
# from tool_input, the call is blocked. Tools not in this list pass
# through — if Claude Code adds new built-in tools, update this map.
has_field() {
  printf '%s' "$2" | jq -e --arg k "$1" '.[$k] // empty' >/dev/null 2>&1
}

check_required() {
  local tool="$1"
  local input="$2"
  case "$tool" in
    Read)
      has_field file_path "$input" ;;
    Edit)
      has_field file_path "$input" && has_field old_string "$input" && has_field new_string "$input" ;;
    Write)
      has_field file_path "$input" && has_field content "$input" ;;
    Bash)
      has_field command "$input" ;;
    NotebookEdit)
      has_field notebook_path "$input" ;;
    mcp__*)
      local key_count
      key_count=$(printf '%s' "$input" | jq 'keys | length')
      [[ "$key_count" -gt 0 ]] ;;
    *)
      return 0 ;;
  esac
}

if check_required "$TOOL_NAME" "$TOOL_INPUT"; then
  exit 0
fi

# ── Empty args detected — likely VH1 streaming parser bug ──

LOG_DIR="${EVAP_SHIELD_LOG_DIR:-$HOME/.claude/logs}"
LOG_FILE="$LOG_DIR/evap-shield.log.jsonl"
COUNTER_DIR="${EVAP_SHIELD_STATE_DIR:-$HOME/.claude/state}"
COUNTER_FILE="$COUNTER_DIR/evap-shield-counter"

mkdir -p "$LOG_DIR" "$COUNTER_DIR"

SESSION_ID=$(printf '%s' "$PAYLOAD" | jq -r '.session_id // "unknown"')

INPUT_KEY_COUNT=$(printf '%s' "$TOOL_INPUT" | jq 'keys | length')
INPUT_KEYS=$(printf '%s' "$TOOL_INPUT" | jq -c '[keys[] | .[0:20]]')

jq -nc --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
       --arg session "$SESSION_ID" \
       --arg tool "$TOOL_NAME" \
       --argjson key_count "$INPUT_KEY_COUNT" \
       --argjson keys "$INPUT_KEYS" \
       '{ts:$ts, session:$session, tool:$tool, arg_keys:$keys, arg_key_count:$key_count}' \
  >> "$LOG_FILE"

# ── Blocked-call counter (per session+tool) ──
COUNTER_KEY="${SESSION_ID}:${TOOL_NAME}"
CURRENT_COUNT=0
if [[ -f "$COUNTER_FILE" ]]; then
  CURRENT_COUNT=$(grep -Fxc -- "$COUNTER_KEY" "$COUNTER_FILE" 2>/dev/null || echo 0)
fi
echo "$COUNTER_KEY" >> "$COUNTER_FILE"
CURRENT_COUNT=$((CURRENT_COUNT + 1))

SEVERITY="WARNING"
ADVICE="Run /clear to reset the session if this persists."
if [[ "$CURRENT_COUNT" -ge 3 ]]; then
  SEVERITY="CRITICAL"
  ADVICE="Run /clear NOW — this session is likely poisoned. Further tool calls will fail."
fi

cat >&2 <<EOF
[$SEVERITY] STREAMING PARSER BUG DETECTED

Tool "$TOOL_NAME" received empty/invalid arguments.
This is a known Claude Code CLI bug where the VH1 streaming JSON parser
silently drops string tokens, causing tool arguments to collapse to {}.

This tool call has been BLOCKED to prevent session poisoning.
Blocked calls in this session: $CURRENT_COUNT

DO NOT retry this tool call — the arguments will be empty again.
$ADVICE

Reference: https://github.com/anthropics/claude-code/issues/62123
EOF
exit 2
