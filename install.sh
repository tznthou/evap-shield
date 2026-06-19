#!/bin/bash
# install.sh — Install evap-shield hooks into Claude Code settings
#
# Usage: bash install.sh [--dry-run]
#
# Installs two hooks, both merged non-destructively and idempotently:
#   - PreToolUse   (evap-shield.sh):  blocks tool calls whose arguments arrived
#                                     empty due to the VH1 streaming parser bug.
#   - SessionStart (check-update.sh): on each start, if Claude Code was updated
#                                     (an update overwrites the binary patch),
#                                     reports whether the patch needs re-applying.

set -euo pipefail

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK_SRC="$SCRIPT_DIR/evap-shield.sh"
CHECK_SRC="$SCRIPT_DIR/check-update.sh"
HOOK_DST="$HOME/.claude/hooks/evap-shield.sh"
CHECK_DST="$HOME/.claude/hooks/check-update.sh"
SETTINGS="$HOME/.claude/settings.json"

# Both hook sources must exist before we touch anything — a partial install
# (one hook copied, settings half-merged) is worse than none.
for src in "$HOOK_SRC" "$CHECK_SRC"; do
  if [[ ! -f "$src" ]]; then
    echo "Error: required hook source not found at $src" >&2
    exit 1
  fi
done

if [[ ! -f "$SETTINGS" ]]; then
  echo "Error: Claude Code settings not found at $SETTINGS" >&2
  echo "Is Claude Code installed?" >&2
  exit 1
fi

echo "evap-shield installer"
echo "====================="
echo ""
echo "PreToolUse   hook: $HOOK_SRC"
echo "SessionStart hook: $CHECK_SRC"
echo "Settings:          $SETTINGS"
echo ""

# ── Idempotency: is each hook already registered? ──
has_pre=false
has_ss=false
if jq -e '.hooks.PreToolUse[]? | select(.hooks[]?.command | test("evap-shield"))' "$SETTINGS" >/dev/null 2>&1; then
  has_pre=true
fi
if jq -e '.hooks.SessionStart[]? | select(.hooks[]?.command | test("check-update"))' "$SETTINGS" >/dev/null 2>&1; then
  has_ss=true
fi

# ── Copy hook scripts ──
if $DRY_RUN; then
  echo "[dry-run] Would copy hook scripts into $HOME/.claude/hooks/"
else
  mkdir -p "$HOME/.claude/hooks"
  cp "$HOOK_SRC"  "$HOOK_DST";  chmod +x "$HOOK_DST"
  cp "$CHECK_SRC" "$CHECK_DST"; chmod +x "$CHECK_DST"
  echo "Copied hook scripts."
fi

# Nothing left to register?
if $has_pre && $has_ss; then
  echo "Both hooks already registered in settings.json — skipping merge."
  echo ""
  echo "Done. evap-shield is active."
  exit 0
fi

# ── Build the hook entries (jq --arg for path safety) ──
PRE_ENTRY=$(jq -nc --arg cmd "$HOOK_DST" \
  '{matcher:"", hooks:[{type:"command", command:$cmd}]}')
# SessionStart fires on new/resumed/cleared sessions; --json makes the hook emit
# hookSpecificOutput (systemMessage to the user, additionalContext to the model).
SS_ENTRY=$(jq -nc --arg cmd "$CHECK_DST --json" \
  '{matcher:"startup|resume|clear", hooks:[{type:"command", command:$cmd}]}')

addpre=false; $has_pre || addpre=true
addss=false;  $has_ss  || addss=true

if $DRY_RUN; then
  echo "[dry-run] Would register in settings.json:"
  $has_pre || echo "  PreToolUse   <- $PRE_ENTRY"
  $has_ss  || echo "  SessionStart <- $SS_ENTRY"
  exit 0
fi

# Backup before modifying
cp "$SETTINGS" "${SETTINGS}.bak-evap-$(date +%s)"

# Atomic write: build in memory → temp → mv
TMPFILE=$(mktemp "${SETTINGS}.tmp.XXXXXX")
trap 'rm -f "$TMPFILE"' EXIT

jq --argjson pre "$PRE_ENTRY" --argjson ss "$SS_ENTRY" \
   --argjson addpre "$addpre" --argjson addss "$addss" '
  .hooks //= {} |
  .hooks.PreToolUse   //= [] |
  .hooks.SessionStart //= [] |
  (if $addpre then .hooks.PreToolUse   += [$pre] else . end) |
  (if $addss  then .hooks.SessionStart += [$ss]  else . end)
' "$SETTINGS" > "$TMPFILE"

# Validate the output is valid JSON before replacing
if jq empty "$TMPFILE" 2>/dev/null; then
  mv "$TMPFILE" "$SETTINGS"
  echo "Registered hooks in settings.json."
else
  rm -f "$TMPFILE"
  echo "Error: generated settings.json is invalid. Original file preserved." >&2
  exit 1
fi

echo ""
echo "Done. evap-shield is active for all new Claude Code sessions."
echo ""
echo "To verify: start a new session and check that the hooks load."
echo "To uninstall: remove the evap-shield / check-update entries from"
echo "  ~/.claude/settings.json and delete the scripts in ~/.claude/hooks/"
