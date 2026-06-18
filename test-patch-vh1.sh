#!/bin/bash
# test-patch-vh1.sh — failure-path regression tests for patch-vh1.sh
#
# These lock down the dangerous parts of the patcher (backup / restore / abort
# rollback / dry-run / SHA guards) that the brick-fix commits added. They use a
# FAKE shell-script "binary" instead of the real ~225 MB CLI, so the suite:
#   - never touches a production binary,
#   - never invokes codesign (a plain-text file isn't Mach-O, so patch-vh1.sh's
#     is_macos_macho() returns false and the signing paths are skipped),
#   - is fast and runnable in CI.
#
# The fake bin carries the VH1 byte pattern in a comment, so detect_pattern()
# classifies it vulnerable/patched; and it prints a version on `--version`, so
# smoke_test_cli() passes. patch-vh1.sh is pointed at it via a throwaway $HOME
# (find_claude_binary picks $HOME/.local/bin/claude) and an isolated
# EVAP_SHIELD_STATE_DIR.
#
# NOT covered (needs a real Mach-O binary): the macOS codesign/re-sign paths
# and the resign-failure -> abort_and_restore trigger. The abort/rollback LOGIC
# itself is covered here via a smoke-test failure instead.
#
# Run: bash test-patch-vh1.sh

set -uo pipefail   # deliberately NOT -e: we assert on non-zero exits

PATCH="$(cd "$(dirname "$0")" && pwd)/patch-vh1.sh"
PASS=0
FAIL=0
ROOT=$(mktemp -d "/tmp/test-patch-vh1.XXXXXX")
trap 'rm -rf "$ROOT"' EXIT

# Full VH1 structural sites patch-vh1.sh matches: ,!<flag>)<recv>.push(...).
# BUG/FIX carry the 2.1.181 minified names (l/n/a); ALT_* carry the 2.1.179 names
# (Y/q/$) — same structure, different identifiers — to prove the patcher binds to
# structure, not to a specific version's variable names (the Bun 1.4 reshuffle).
BUG=',!l)n.push({type:"string",value:a})'
FIX=',!0)n.push({type:"string",value:a})'
ALT_BUG=',!Y)q.push({type:"string",value:$})'
ALT_FIX=',!0)q.push({type:"string",value:$})'
# children.push near-miss (value followed by ,offset): single source of truth
# shared by the `mixed` fixture and case 3d's "left intact" assertion.
CHILD=',!m)x.push({type:"string",value:b,offset:o})'

ok() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
bad() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

# assert <desc> <actual> <expected>
assert() { [[ "$2" == "$3" ]] && ok "$1" || bad "$1 (want '$3', got '$2')"; }
# assert_has <desc> <file> <needle>
assert_has() { grep -qF "$3" "$2" 2>/dev/null && ok "$1" || bad "$1 (missing '$3')"; }

sha() { shasum -a 256 "$1" | cut -d' ' -f1; }

# make_fake_bin <dest> <kind>
make_fake_bin() {
  local dest="$1" kind="$2"
  case "$kind" in
    vulnerable)     printf '#!/bin/bash\necho "2.1.179 (Claude Code)"\n# %s\n' "$BUG" >"$dest" ;;
    vulnerable_alt) printf '#!/bin/bash\necho "2.1.179 (Claude Code)"\n# %s\n' "$ALT_BUG" >"$dest" ;;
    patched)        printf '#!/bin/bash\necho "2.1.179 (Claude Code)"\n# %s\n' "$FIX" >"$dest" ;;
    unknown)        printf '#!/bin/bash\necho "2.1.179 (Claude Code)"\n# no vh1 marker\n' >"$dest" ;;
    double)         printf '#!/bin/bash\necho "2.1.179 (Claude Code)"\n# %s\n# %s\n' "$BUG" "$BUG" >"$dest" ;;
    # Negative space (Codex review): shapes that must NOT be patched as the VH1 site.
    numguard)       printf '#!/bin/bash\necho "2.1.179 (Claude Code)"\n# %s\n' ',!1)n.push({type:"string",value:a})' >"$dest" ;;
    multichar)      printf '#!/bin/bash\necho "2.1.179 (Claude Code)"\n# %s\n' ',!aa)n.push({type:"string",value:a})' >"$dest" ;;
    childnode)      printf '#!/bin/bash\necho "2.1.179 (Claude Code)"\n# %s\n' ',!l)n.push({type:"string",value:a,offset:o})' >"$dest" ;;
    mixed)          printf '#!/bin/bash\necho "2.1.179 (Claude Code)"\n# %s\n# %s\n' "$BUG" "$CHILD" >"$dest" ;;
    # Launches fine while vulnerable (!l); once patched (!0) `--version` exits 1,
    # so the post-patch smoke_test_cli fails and triggers abort_and_restore.
    smokefail)      printf '#!/bin/bash\ngrep -qF %s "$0" && exit 1\necho "2.1.179 (Claude Code)"\n# %s\n' "'$FIX'" "$BUG" >"$dest" ;;
  esac
  chmod +x "$dest"
}

# new_home <tag> <kind> -> prints the home dir; fake bin at $home/.local/bin/claude
new_home() {
  local h="$ROOT/$1"
  mkdir -p "$h/.local/bin" "$h/state"
  make_fake_bin "$h/.local/bin/claude" "$2"
  echo "$h"
}

BIN_REL=".local/bin/claude"

# run_patch <home> <args...> ; sets global RC + writes $home/out,$home/err
run_patch() {
  local h="$1"; shift
  HOME="$h" EVAP_SHIELD_STATE_DIR="$h/state" bash "$PATCH" "$@" >"$h/out" 2>"$h/err"
  RC=$?
}

echo "=== patch-vh1.sh failure-path test suite ==="
echo ""

# ── 1. --status on a vulnerable binary ──
echo "── status / dry-run ──"
H=$(new_home c1 vulnerable)
run_patch "$H" --status
assert "status: exit 0" "$RC" "0"
assert_has "status: reports vulnerable" "$H/out" "vulnerable"

# ── 2. --dry-run must not touch the binary, backup, or state ──
H=$(new_home c2 vulnerable)
BEFORE=$(sha "$H/$BIN_REL")
run_patch "$H" --dry-run
assert "dry-run: exit 0" "$RC" "0"
assert "dry-run: binary unchanged" "$(sha "$H/$BIN_REL")" "$BEFORE"
[[ ! -e "$H/state/patch-vh1.json" ]] && ok "dry-run: no state file" || bad "dry-run: state file created"
[[ ! -d "$H/state/patch-backups" ]] && ok "dry-run: no backup dir" || bad "dry-run: backup created"

# ── 3. happy patch: applies fix, backs up original, saves state ──
echo ""
echo "── patch apply ──"
H=$(new_home c3 vulnerable)
ORIG=$(sha "$H/$BIN_REL")
run_patch "$H"
assert "patch: exit 0" "$RC" "0"
assert_has "patch: binary now has FIX bytes" "$H/$BIN_REL" "$FIX"
grep -qF "$BUG" "$H/$BIN_REL" && bad "patch: BUG bytes still present" || ok "patch: BUG bytes gone"
[[ -f "$H/state/patch-vh1.json" ]] && ok "patch: state file written" || bad "patch: no state file"
BK="$H/state/patch-backups/${ORIG:0:12}.bin"
[[ -f "$BK" ]] && ok "patch: backup created" || bad "patch: no backup"
assert "patch: backup == original bytes" "$(sha "$BK")" "$ORIG"

# ── 3b. version-agnostic: patch a binary with DIFFERENT minified names ──
# Complements #3: #3's BUG fixture uses the 2.1.181 names (l/n/a) — the shape
# that actually broke the old hardcoded ',!Y)q.push' matcher. This case feeds the
# OTHER shape (2.1.179 names Y/q/$) to prove the structural matcher patches it
# regardless of which identifiers the minifier picked. The two fixtures together
# pin both directions: neither variable set may be hardcoded.
H=$(new_home c3b vulnerable_alt)
run_patch "$H"
assert "alt-names: exit 0" "$RC" "0"
assert_has "alt-names: patched to FIX bytes" "$H/$BIN_REL" "$ALT_FIX"
grep -qF "$ALT_BUG" "$H/$BIN_REL" && bad "alt-names: BUG bytes still present" || ok "alt-names: BUG bytes gone"

# ── 3c. negative space: shapes that must NOT be treated as the VH1 site ──
# Locks the matcher's safety boundary (Codex review): a digit guard (!1 is a
# minified `false`, not a variable), a multi-char flag, and a children.push
# near-miss (value followed by ,offset — excluded by the }) anchor). All three
# must be classified unknown and refused, never silently mis-patched.
for kind in numguard multichar childnode; do
  H=$(new_home "neg-$kind" "$kind")
  run_patch "$H"
  assert "neg/$kind: refused (exit 1)" "$RC" "1"
  assert_has "neg/$kind: reported unknown" "$H/err" "not found"
done

# ── 3d. mixed: a real VH1 site next to a children.push near-miss ──
# Real-binary layout — the string push and a children.push coexist. The matcher
# must patch ONLY the VH1 site and leave the children.push ($CHILD) byte-for-byte
# intact.
H=$(new_home c3d mixed)
run_patch "$H"
assert "mixed: exit 0" "$RC" "0"
assert_has "mixed: VH1 site patched" "$H/$BIN_REL" "$FIX"
assert_has "mixed: children.push left intact" "$H/$BIN_REL" "$CHILD"

# ── 4. already-patched binary: no-op, exit 0 ──
H=$(new_home c4 patched)
run_patch "$H"
assert "already-patched: exit 0" "$RC" "0"
assert_has "already-patched: says so" "$H/out" "Already patched"

# ── 5. unknown pattern: refuse, exit 1 ──
H=$(new_home c5 unknown)
run_patch "$H"
assert "unknown: exit 1" "$RC" "1"
assert_has "unknown: explains pattern not found" "$H/err" "not found"

# ── 6. multiple occurrences: refuse, exit 1 ──
H=$(new_home c6 double)
run_patch "$H"
assert "double: exit 1" "$RC" "1"
assert_has "double: refuses ambiguous patch" "$H/err" "occurrences"

# ── 7. restore happy path ──
echo ""
echo "── restore ──"
H=$(new_home c7 vulnerable)
ORIG=$(sha "$H/$BIN_REL")
run_patch "$H"                       # patch first
run_patch "$H" --restore
assert "restore: exit 0" "$RC" "0"
assert "restore: binary back to original" "$(sha "$H/$BIN_REL")" "$ORIG"
[[ ! -f "$H/state/patch-vh1.json" ]] && ok "restore: state cleared" || bad "restore: state remains"

# ── 8. restore refuses a tampered backup (SHA guard) ──
H=$(new_home c8 vulnerable)
run_patch "$H"
PATCHED=$(sha "$H/$BIN_REL")
echo "# tampered" >>"$H"/state/patch-backups/*.bin   # corrupt the backup
run_patch "$H" --restore
assert "tampered-backup: exit 1" "$RC" "1"
assert "tampered-backup: binary NOT overwritten" "$(sha "$H/$BIN_REL")" "$PATCHED"
assert_has "tampered-backup: reports hash mismatch" "$H/err" "mismatch"

# ── 9. restore with a missing backup ──
H=$(new_home c9 vulnerable)
run_patch "$H"
PATCHED=$(sha "$H/$BIN_REL")
rm -f "$H"/state/patch-backups/*.bin
run_patch "$H" --restore
assert "missing-backup: exit 1" "$RC" "1"
assert "missing-backup: binary unchanged" "$(sha "$H/$BIN_REL")" "$PATCHED"
assert_has "missing-backup: reports not found" "$H/err" "not found"

# ── 10. restore refuses when current binary != recorded patched SHA ──
H=$(new_home c10 vulnerable)
run_patch "$H"
echo "# drifted" >>"$H/$BIN_REL"                     # binary changed since patch
run_patch "$H" --restore
assert "stale-binary: exit 1" "$RC" "1"
assert_has "stale-binary: refuses unsafe restore" "$H/err" "match"

# ── 11. abort_and_restore rolls back when post-patch smoke test fails ──
echo ""
echo "── abort / rollback ──"
H=$(new_home c11 smokefail)
ORIG=$(sha "$H/$BIN_REL")
run_patch "$H"
assert "abort: exit 1" "$RC" "1"
assert "abort: binary rolled back to original" "$(sha "$H/$BIN_REL")" "$ORIG"
assert_has "abort: announces restore" "$H/out" "Restoring"
[[ ! -f "$H/state/patch-vh1.json" ]] && ok "abort: no state saved" || bad "abort: state saved despite failure"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
