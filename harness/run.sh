#!/usr/bin/env bash
# 模式 D 單次實驗: run.sh <binary> <mode> <port> <tag>
# 完全隔離: 自建 HOME/CLAUDE_CONFIG_DIR, 假 API key, 不碰 prod 設定或資料
set -u
BIN="$1"; MODE="$2"; PORT="$3"; TAG="$4"
BASE="$(cd "$(dirname "$0")" && pwd)"
OUT="$BASE/out"; mkdir -p "$OUT"
SANDBOX="$BASE/sandbox-$TAG"; rm -rf "$SANDBOX"; mkdir -p "$SANDBOX/home" "$SANDBOX/proj"

APILOG="$OUT/api-$TAG.log"
CCOUT="$OUT/cc-$TAG.out"
CCERR="$OUT/cc-$TAG.err"

PROBE_MODE="$MODE" python3 "$BASE/fake_api_missing_block.py" "$PORT" "$APILOG" &
SRV=$!
trap 'kill $SRV 2>/dev/null' EXIT
sleep 1

cd "$SANDBOX/proj"
HOME="$SANDBOX/home" \
CLAUDE_CONFIG_DIR="$SANDBOX/home/.claude" \
ANTHROPIC_BASE_URL="http://127.0.0.1:$PORT" \
ANTHROPIC_API_KEY=fake \
ANTHROPIC_MODEL=claude-opus-5 \
DISABLE_TELEMETRY=1 DISABLE_ERROR_REPORTING=1 DISABLE_AUTOUPDATER=1 \
  "$BIN" -p "run: echo hello" --output-format json \
  >"$CCOUT" 2>"$CCERR" &
CCPID=$!
( sleep 45; kill -9 $CCPID 2>/dev/null ) &
WATCHER=$!
wait $CCPID; RC=$?
kill $WATCHER 2>/dev/null

kill $SRV 2>/dev/null
echo "=== [$TAG] binary=$(basename $BIN) mode=$MODE exit=$RC ==="
echo "--- stdout ---"; cat "$CCOUT"
echo "--- stderr (tail) ---"; tail -20 "$CCERR"
echo "--- api log ---"; cat "$APILOG"
