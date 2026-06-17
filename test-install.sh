#!/bin/bash
# Test suite for install.sh
# Verifies the settings.json merge NEVER clobbers existing user config and is
# idempotent. Every test runs against an isolated fake HOME — the real
# ~/.claude/settings.json is never touched.
# Run: bash test-install.sh

set -euo pipefail

INSTALLER="$(cd "$(dirname "$0")" && pwd)/install.sh"
PASS=0
FAIL=0

WORKROOT=$(mktemp -d)
trap 'rm -rf "$WORKROOT"' EXIT

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

# Build an isolated fake HOME with the given settings.json; sets $THOME.
THOME=""
new_home() {
  local name="$1" settings="$2"
  THOME="$WORKROOT/$name"
  mkdir -p "${THOME}/.claude"
  printf '%s' "$settings" > "${THOME}/.claude/settings.json"
}

# Assert a jq expression is truthy against a settings file.
assert_jq() {
  local desc="$1" file="$2" expr="$3"
  if jq -e "$expr" "$file" >/dev/null 2>&1; then pass "$desc"; else fail "$desc (jq: $expr)"; fi
}

EVAP_FILTER='[.hooks.PreToolUse[]? | select(.hooks[]?.command | test("evap-shield"))] | length'

echo "=== install.sh test suite ==="
echo ""
echo "── Merge must preserve existing config ──"

# 1. Empty settings — evap added, result still a valid object
new_home empty '{}'
HOME="$THOME" bash "$INSTALLER" >/dev/null 2>&1
assert_jq "empty settings: result is an object" "${THOME}/.claude/settings.json" 'type == "object"'
assert_jq "empty settings: evap added exactly once" "${THOME}/.claude/settings.json" "$EVAP_FILTER == 1"

# 2. Unrelated top-level keys must survive
new_home keepkeys '{"model":"opus","theme":"dark","arr":[1,2,3]}'
HOME="$THOME" bash "$INSTALLER" >/dev/null 2>&1
assert_jq "preserves .model" "${THOME}/.claude/settings.json" '.model == "opus"'
assert_jq "preserves .theme" "${THOME}/.claude/settings.json" '.theme == "dark"'
assert_jq "preserves arbitrary array key" "${THOME}/.claude/settings.json" '.arr == [1,2,3]'
assert_jq "evap added" "${THOME}/.claude/settings.json" "$EVAP_FILTER == 1"

# 3. hooks exists but no PreToolUse — other hook types must survive
new_home nopretool '{"hooks":{"PostToolUse":[{"matcher":"","hooks":[{"type":"command","command":"/my/post.sh"}]}]}}'
HOME="$THOME" bash "$INSTALLER" >/dev/null 2>&1
assert_jq "preserves PostToolUse" "${THOME}/.claude/settings.json" '.hooks.PostToolUse[0].hooks[0].command == "/my/post.sh"'
assert_jq "adds PreToolUse with evap" "${THOME}/.claude/settings.json" "$EVAP_FILTER == 1"

# 4. Existing user PreToolUse hook must be kept, evap appended (not overwritten)
new_home userhook '{"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"/my/precheck.sh"}]}]}}'
HOME="$THOME" bash "$INSTALLER" >/dev/null 2>&1
assert_jq "keeps user Bash hook" "${THOME}/.claude/settings.json" '[.hooks.PreToolUse[] | select(.hooks[]?.command == "/my/precheck.sh")] | length == 1'
assert_jq "appends evap (PreToolUse now 2)" "${THOME}/.claude/settings.json" '.hooks.PreToolUse | length == 2'

echo ""
echo "── Idempotency ──"

# 5. Running twice must not duplicate the hook or pile up backups
new_home idem '{}'
HOME="$THOME" bash "$INSTALLER" >/dev/null 2>&1
HOME="$THOME" bash "$INSTALLER" >/dev/null 2>&1
assert_jq "evap still appears exactly once after 2 runs" "${THOME}/.claude/settings.json" "$EVAP_FILTER == 1"
backups=$(find "${THOME}/.claude" -name 'settings.json.bak-evap-*' | wc -l | tr -d ' ')
if [[ "$backups" == "1" ]]; then pass "2nd run skipped: only 1 backup"; else fail "expected 1 backup, got $backups"; fi

echo ""
echo "── --dry-run must not mutate anything ──"

# 6. dry-run leaves settings + hook dir untouched
new_home dry '{"existing":"untouched"}'
before=$(cat "${THOME}/.claude/settings.json")
HOME="$THOME" bash "$INSTALLER" --dry-run >/dev/null 2>&1
after=$(cat "${THOME}/.claude/settings.json")
if [[ "$before" == "$after" ]]; then pass "dry-run: settings.json unchanged"; else fail "dry-run: settings.json was modified"; fi
if [[ ! -f "${THOME}/.claude/hooks/evap-shield.sh" ]]; then pass "dry-run: hook not copied"; else fail "dry-run: hook was copied"; fi

echo ""
echo "── Error handling (must exit non-zero, no partial write) ──"

# 7. Missing settings.json — abort
mkdir -p "$WORKROOT/nosettings/.claude"
if HOME="$WORKROOT/nosettings" bash "$INSTALLER" >/dev/null 2>&1; then
  fail "missing settings: should exit non-zero"
else
  pass "missing settings: exits non-zero"
fi

# 8. Missing source evap-shield.sh — abort (run installer copy from a dir with no hook source)
mkdir -p "$WORKROOT/isol"
cp "$INSTALLER" "$WORKROOT/isol/install.sh"
new_home nosrc '{}'
if HOME="$THOME" bash "$WORKROOT/isol/install.sh" >/dev/null 2>&1; then
  fail "missing source: should exit non-zero"
else
  pass "missing source: exits non-zero"
fi
# And the settings.json must be left untouched when source is missing
assert_jq "missing source: settings.json left untouched" "${THOME}/.claude/settings.json" '. == {}'

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
