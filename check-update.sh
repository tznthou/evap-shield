#!/bin/bash
# check-update.sh — Detect Claude Code updates and report VH1 patch status
#
# Built to run as a SessionStart hook. On each session start it cheaply
# fingerprints the live Claude Code binary; ONLY when that fingerprint changed
# since last run (Claude Code was updated, which overwrites any binary patch)
# does it run a VH1 status check and report whether the patch needs re-applying.
#
# Scope (stage 1): detect + test + report. It never patches and never edits
# docs — those need judgement and stay manual. When nothing changed it is
# silent and near-instant (a stat-only fast path, no hashing, no binary scan),
# so it does not slow down normal startup.
#
# It only speaks when you need to act:
#   - vulnerable  -> the update wiped the patch; re-run patch-vh1.sh
#   - unknown     -> the parser pattern is gone; may be fixed upstream, verify
#   - patched / unchanged -> stays quiet
#
# Usage:
#   bash check-update.sh           # human-readable report (silent if no change)
#   bash check-update.sh --json    # JSON hookSpecificOutput (for the hook)
#   bash check-update.sh --force   # always report current state (testing)
#
# SessionStart hook entry (~/.claude/settings.json):
#   "SessionStart": [{ "matcher": "startup|resume|clear",
#     "hooks": [{ "type": "command",
#                 "command": "$HOME/.claude/hooks/check-update.sh --json" }] }]
#
# See: https://github.com/anthropics/claude-code/issues/62123

# Deliberately NOT `set -e`: a detector must fail open, not abort. A failed
# `[[ ]]` test or a missing file should never break (or even noise up) startup.
set -uo pipefail

JSON=false
FORCE=false
for arg in "$@"; do
  case "$arg" in
    --json)  JSON=true ;;
    --force) FORCE=true ;;
    *) ;;  # stay permissive — the hook may be invoked with extra args
  esac
done

STATE_DIR="${EVAP_SHIELD_STATE_DIR:-$HOME/.claude/state}"
SEEN_FILE="$STATE_DIR/evap-shield-seen.json"

# SessionStart delivers a JSON payload on stdin. Drain it so the writer never
# blocks on a full pipe; we don't need any field from it.
if [[ ! -t 0 ]]; then
  cat >/dev/null 2>&1 || true
fi

# jq is required to emit/parse JSON state. Without it, fail open silently
# rather than spam every single startup with an error.
command -v jq >/dev/null 2>&1 || exit 0

# ── Locate the live binary (mirrors patch-vh1.sh's resolution, kept local so
# the fast path needs nothing from the patcher) ──
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
  echo ""
}

CLI_BIN=$(find_claude_binary)
[[ -z "$CLI_BIN" || ! -f "$CLI_BIN" ]] && exit 0

# ── Fast fingerprint: resolved path | size | mtime ──
# stat only — no hashing, no python scan. A version switch changes the resolved
# path; an in-place patch or a repack changes size/mtime. If this matches last
# run, Claude Code wasn't updated and the patch can't have been overwritten.
fingerprint() {
  local size mtime
  size=$(wc -c < "$CLI_BIN" 2>/dev/null | tr -d ' ')
  mtime=$(stat -f %m "$CLI_BIN" 2>/dev/null || stat -c %Y "$CLI_BIN" 2>/dev/null || echo 0)
  echo "${CLI_BIN}|${size}|${mtime}"
}

# ── VH1 status, computed standalone ──
# No dependency on patch-vh1.sh, so this hook deploys as one self-contained
# file. Same structural anchor patch-vh1.sh uses (,!<flag>)<recv>.push({type:
# "string",value:<acc>}) where flag 0 == patched); both scripts carry their own
# tests. Sets VERSION + STATUS. Only runs on the slow path (binary changed).
detect_status() {
  VERSION=$(strings "$CLI_BIN" 2>/dev/null | grep -o '"2\.[0-9]*\.[0-9]*"' | tail -1 | tr -d '"')
  [[ -z "$VERSION" ]] && VERSION="unknown"
  local res bug fix
  res=$(python3 - "$CLI_BIN" 2>/dev/null <<'PY'
import re, sys
try:
    data = open(sys.argv[1], 'rb').read()
except Exception:
    print("0 0"); sys.exit(0)
PAT = re.compile(
    rb',!([A-Za-z_$0])\)'
    rb'(?:[A-Za-z_$][A-Za-z_$0-9]*)'
    rb'\.push\(\{type:"string",value:'
    rb'(?:[A-Za-z_$][A-Za-z_$0-9]*)\}\)'
)
vuln = patched = 0
for m in PAT.finditer(data):
    if m.group(1) == b'0':
        patched += 1
    else:
        vuln += 1
print(f'{vuln} {patched}')
PY
)
  bug=$(printf '%s' "$res" | cut -d' ' -f1)
  fix=$(printf '%s' "$res" | cut -d' ' -f2)
  [[ "$bug" =~ ^[0-9]+$ ]] || bug=0
  [[ "$fix" =~ ^[0-9]+$ ]] || fix=0
  if   [[ "$bug" -gt 0 ]]; then STATUS="vulnerable"
  elif [[ "$fix" -gt 0 ]]; then STATUS="patched"
  else                          STATUS="unknown"; fi
}

CUR_FP=$(fingerprint)

PREV_FP=""
PREV_VERSION=""
if [[ -f "$SEEN_FILE" ]]; then
  PREV_FP=$(jq -r '.fingerprint // ""' "$SEEN_FILE" 2>/dev/null || echo "")
  PREV_VERSION=$(jq -r '.version // ""' "$SEEN_FILE" 2>/dev/null || echo "")
fi

# Unchanged and not forced -> silent fast path (the common case).
if [[ "$FORCE" != true && -n "$PREV_FP" && "$CUR_FP" == "$PREV_FP" ]]; then
  exit 0
fi

# ── Changed (or first run / forced): compute version + VH1 status ──
VERSION="unknown"; STATUS="unknown"
detect_status

FIRST_RUN=false
[[ -z "$PREV_FP" ]] && FIRST_RUN=true

# ── Compose the verdict (only vulnerable/unknown warrant user action) ──
# "What changed" prefix: a first run is a discovery, not an update, so it
# states the bare version instead of a bogus "updated ? -> X".
if [[ "$FIRST_RUN" == true ]]; then
  CHANGE="evap-shield: Claude Code $VERSION"
else
  CHANGE="evap-shield: Claude Code updated ${PREV_VERSION:-?} -> $VERSION"
fi
HEADLINE=""; DETAIL=""; ACTION=""; SEVERITY="info"
case "$STATUS" in
  vulnerable)
    SEVERITY="warn"
    if [[ "$FIRST_RUN" == true ]]; then
      HEADLINE="$CHANGE is NOT patched against the VH1 bug."
    else
      HEADLINE="$CHANGE — the VH1 patch was overwritten."
    fi
    DETAIL="Tool arguments can silently collapse to {} again until re-patched."
    ACTION="Re-apply:  bash patch-vh1.sh"
    ;;
  patched)
    SEVERITY="info"
    HEADLINE="$CHANGE — VH1 patch is in place."
    DETAIL="No action needed."
    ;;
  unknown)
    SEVERITY="warn"
    HEADLINE="$CHANGE — VH1 parser pattern not found."
    DETAIL="The parser may have been restructured upstream (possibly fixed), or the patcher no longer matches."
    ACTION="Verify:  bash patch-vh1.sh --status"
    ;;
esac

# ── Emit ──
emit_plain() {
  # Only vulnerable/unknown (warn) warrant interrupting; patched/info stays
  # quiet unless --force explicitly asks for a confirmation.
  if [[ "$SEVERITY" != "warn" && "$FORCE" != true ]]; then
    return 0
  fi
  [[ -z "$HEADLINE" ]] && return 0
  echo "$HEADLINE"
  [[ -n "$DETAIL"  ]] && echo "  $DETAIL"
  [[ -n "$ACTION"  ]] && echo "  $ACTION"
}

emit_json() {
  local ctx="evap-shield update check: Claude Code now $VERSION, VH1 status=$STATUS."
  [[ -n "$HEADLINE" ]] && ctx="$HEADLINE ${DETAIL} ${ACTION}"
  if [[ "$SEVERITY" == "warn" ]]; then
    # systemMessage -> shown directly to the user; additionalContext -> model.
    jq -nc --arg ctx "$ctx" --arg sys "$HEADLINE  $ACTION" \
      '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$ctx,systemMessage:$sys}}'
  else
    # patched/changed: let the model know, don't interrupt the user.
    jq -nc --arg ctx "$ctx" \
      '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$ctx,suppressOutput:true}}'
  fi
}

if [[ "$JSON" == true ]]; then
  emit_json
else
  emit_plain
fi

# ── Persist the new fingerprint so a given change is reported only once ──
mkdir -p "$STATE_DIR" 2>/dev/null || true
TMP=$(mktemp "${SEEN_FILE}.XXXXXX" 2>/dev/null || echo "")
if [[ -n "$TMP" ]]; then
  if jq -nc --arg fp "$CUR_FP" --arg v "$VERSION" --arg st "$STATUS" \
        --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '{fingerprint:$fp, version:$v, status:$st, checked_at:$at}' \
        > "$TMP" 2>/dev/null; then
    mv -f "$TMP" "$SEEN_FILE" 2>/dev/null || rm -f "$TMP"
  else
    rm -f "$TMP"
  fi
fi

exit 0
