#!/bin/bash
# evap-shield.sh — PreToolUse hook
# Detects and blocks tool calls whose arguments evaporated to empty — the
# signature of the Claude Code VH1 streaming parser bug (#62123, #67765).
#
# MCP tools carry no schema a hook can read, so a bare {} is only suspicious
# in context. The gate is per-session history:
#   - non-empty call      -> remember session:tool in the history file, pass
#   - {} with history     -> this tool sent real arguments earlier in the
#                            session, then went empty: the VH1 poisoning
#                            signature (a poisoned tool stays empty). BLOCK.
#   - {} without history  -> may be a legitimately zero-argument tool
#                            (e.g. list/context tools). Pass, but log it.
# Built-in tools use the required-field map below. In practice Claude Code's
# own validation rejects built-in {} before PreToolUse hooks run, so that map
# is completeness, not the working surface.
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
SESSION_ID=$(printf '%s' "$PAYLOAD" | jq -r '.session_id // "unknown"')

LOG_DIR="${EVAP_SHIELD_LOG_DIR:-$HOME/.claude/logs}"
LOG_FILE="$LOG_DIR/evap-shield.log.jsonl"
STATE_DIR="${EVAP_SHIELD_STATE_DIR:-$HOME/.claude/state}"
COUNTER_FILE="$STATE_DIR/evap-shield-counter"
HISTORY_FILE="$STATE_DIR/evap-shield-nonempty"

# log_event <action> — one redacted JSONL line: tool name and argument key
# names only, never argument values (paths, code, user data stay out).
log_event() {
  mkdir -p "$LOG_DIR"
  local key_count keys
  key_count=$(printf '%s' "$TOOL_INPUT" | jq 'keys | length')
  keys=$(printf '%s' "$TOOL_INPUT" | jq -c '[keys[] | .[0:20]]')
  jq -nc --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
         --arg session "$SESSION_ID" \
         --arg tool "$TOOL_NAME" \
         --arg action "$1" \
         --argjson key_count "$key_count" \
         --argjson keys "$keys" \
         '{ts:$ts, session:$session, tool:$tool, action:$action, arg_keys:$keys, arg_key_count:$key_count}' \
    >> "$LOG_FILE"
}

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
    *)
      return 0 ;;
  esac
}

# ── Decide: pass, or fall through to the block path with EVIDENCE set ──
EVIDENCE=""
case "$TOOL_NAME" in
  mcp__*)
    KEY_COUNT=$(printf '%s' "$TOOL_INPUT" | jq 'keys | length')
    HIST_KEY="${SESSION_ID}:${TOOL_NAME}"
    if [[ "$KEY_COUNT" -gt 0 ]]; then
      # Real arguments: remember that this tool takes arguments, then pass.
      mkdir -p "$STATE_DIR"
      grep -Fxq -- "$HIST_KEY" "$HISTORY_FILE" 2>/dev/null || echo "$HIST_KEY" >> "$HISTORY_FILE"
      exit 0
    fi
    if ! grep -Fxq -- "$HIST_KEY" "$HISTORY_FILE" 2>/dev/null; then
      # First {} for this tool in this session: hooks can't see MCP schemas,
      # and legitimately zero-argument tools exist — a bare {} with no history
      # is more likely a legal call than VH1. Pass, keep a trace for triage.
      log_event allowed
      exit 0
    fi
    EVIDENCE="Tool \"$TOOL_NAME\" was called with {} after sending non-empty arguments earlier in this session — the VH1 poisoning signature (a poisoned tool goes empty and stays empty)."
    ;;
  *)
    if check_required "$TOOL_NAME" "$TOOL_INPUT"; then
      exit 0
    fi
    EVIDENCE="Tool \"$TOOL_NAME\" was called with required arguments missing."
    ;;
esac

# ── Empty args with poisoning evidence — block ──

log_event blocked

# ── Blocked-call counter (per session+tool) ──
COUNTER_KEY="${SESSION_ID}:${TOOL_NAME}"
CURRENT_COUNT=0
if [[ -f "$COUNTER_FILE" ]]; then
  # `grep -c` prints 0 AND exits 1 on no match — `|| echo 0` here would stack
  # a second line onto the count ("0\n0") and break the arithmetic below.
  CURRENT_COUNT=$(grep -Fxc -- "$COUNTER_KEY" "$COUNTER_FILE" 2>/dev/null || true)
  [[ "$CURRENT_COUNT" =~ ^[0-9]+$ ]] || CURRENT_COUNT=0
fi
mkdir -p "$STATE_DIR"
echo "$COUNTER_KEY" >> "$COUNTER_FILE"
CURRENT_COUNT=$((CURRENT_COUNT + 1))

SEVERITY="WARNING"
ADVICE="Run /clear to reset the session if this persists."
if [[ "$CURRENT_COUNT" -ge 3 ]]; then
  SEVERITY="CRITICAL"
  ADVICE="Run /clear NOW — this session is likely poisoned. Further tool calls will fail."
fi

cat >&2 <<EOF
[$SEVERITY] EMPTY TOOL ARGUMENTS BLOCKED

$EVIDENCE

This matches the Claude Code VH1 streaming parser bug (#62123): a dropped
string token makes every later call to the same tool collapse to {}.
This call was BLOCKED to prevent acting on evaporated arguments.
Blocked calls in this session: $CURRENT_COUNT

Do not retry the identical call — if the bug is active, the arguments will
be empty again. $ADVICE
If you genuinely intended a zero-argument call here, include at least one
argument, or tell the user evap-shield blocked an intentional empty call.

Reference: https://github.com/anthropics/claude-code/issues/62123
EOF
exit 2
