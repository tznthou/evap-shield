#!/bin/bash
# install.sh — Install evap-shield hook into Claude Code settings
#
# Usage: bash install.sh [--dry-run]
#
# Adds a PreToolUse hook that detects and blocks tool calls with empty
# arguments caused by the VH1 streaming parser bug.

set -euo pipefail

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK_SRC="$SCRIPT_DIR/evap-shield.sh"
HOOK_DST="$HOME/.claude/hooks/evap-shield.sh"
SETTINGS="$HOME/.claude/settings.json"

if [[ ! -f "$HOOK_SRC" ]]; then
  echo "Error: evap-shield.sh not found at $HOOK_SRC" >&2
  exit 1
fi

if [[ ! -f "$SETTINGS" ]]; then
  echo "Error: Claude Code settings not found at $SETTINGS" >&2
  echo "Is Claude Code installed?" >&2
  exit 1
fi

echo "evap-shield installer"
echo "====================="
echo ""
echo "Source: $HOOK_SRC"
echo "Target: $HOOK_DST"
echo ""

# Copy hook script
if $DRY_RUN; then
  echo "[dry-run] Would copy $HOOK_SRC → $HOOK_DST"
else
  mkdir -p "$(dirname "$HOOK_DST")"
  cp "$HOOK_SRC" "$HOOK_DST"
  chmod +x "$HOOK_DST"
  echo "Copied hook script."
fi

# Check if hook is already registered
if jq -e '.hooks.PreToolUse[]? | select(.hooks[]?.command | test("evap-shield"))' "$SETTINGS" >/dev/null 2>&1; then
  echo "Hook already registered in settings.json — skipping."
  echo ""
  echo "Done. evap-shield is active."
  exit 0
fi

# Build the hook entry (jq --arg for path safety)
HOOK_ENTRY=$(jq -nc --arg cmd "$HOOK_DST" '{matcher:"", hooks:[{type:"command", command:$cmd}]}')

if $DRY_RUN; then
  echo "[dry-run] Would add to settings.json hooks.PreToolUse:"
  echo "$HOOK_ENTRY" | jq .
else
  # Backup before modifying
  cp "$SETTINGS" "${SETTINGS}.bak-evap-$(date +%s)"

  # Atomic write: build in memory → write to temp → mv
  TMPFILE=$(mktemp "${SETTINGS}.tmp.XXXXXX")
  trap 'rm -f "$TMPFILE"' EXIT

  jq --argjson entry "$HOOK_ENTRY" '
    .hooks //= {} |
    .hooks.PreToolUse //= [] |
    .hooks.PreToolUse += [$entry]
  ' "$SETTINGS" > "$TMPFILE"

  # Validate the output is valid JSON before replacing
  if jq empty "$TMPFILE" 2>/dev/null; then
    mv "$TMPFILE" "$SETTINGS"
    echo "Registered hook in settings.json."
  else
    rm -f "$TMPFILE"
    echo "Error: generated settings.json is invalid. Original file preserved." >&2
    exit 1
  fi
fi

echo ""
echo "Done. evap-shield is active for all new Claude Code sessions."
echo ""
echo "To verify: start a new session and check that the hook loads."
echo "To uninstall: remove the evap-shield entry from ~/.claude/settings.json"
echo "  and delete ~/.claude/hooks/evap-shield.sh"
