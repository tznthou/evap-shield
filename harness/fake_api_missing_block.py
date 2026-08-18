"""模式 D harness — tool_use block 遺失的三個變體.

沿用 2026-08-17 fake_api.py 的骨架, 換掉 SSE 序列.

PROBE_MODE:
  dropblock   D1: 只有 text block 宣告要用工具, stop_reason=tool_use 但零 tool_use block
  halfblock   D2: content_block_start(tool_use) 後直接收尾, 無 delta 無 content_block_stop
  emptyblock  D3: 結構完整的 tool_use block 但零 input_json_delta (input 留 {})

第一輪送壞 stream, 第二輪起送正常 end_turn, 避免無限重試並觀測 client 送回什麼.
"""
import json, os, sys, threading
from http.server import BaseHTTPRequestHandler, HTTPServer

LOG = open(sys.argv[2] if len(sys.argv) > 2 else '/tmp/fake_api.log', 'w')
MODE = os.environ.get('PROBE_MODE', 'dropblock')

TURN = {'n': 0}
LOCK = threading.Lock()


def sse(ev, obj):
    return f"event: {ev}\ndata: {json.dumps(obj)}\n\n".encode()


class H(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def _log(self, tag, extra=""):
        LOG.write(f"{tag} {self.path} {extra}\n")
        LOG.flush()

    def do_GET(self):
        self._log("GET")
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(b'{}')

    def do_POST(self):
        n = int(self.headers.get('Content-Length') or 0)
        body = self.rfile.read(n) if n else b''
        try:
            req = json.loads(body)
        except Exception:
            req = {}

        if 'count_tokens' in self.path:
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(b'{"input_tokens":10}')
            return

        tools = req.get('tools') or []
        is_main = len(tools) > 0     # title generation / 各種輔助請求不帶 tools
        with LOCK:
            if is_main:
                TURN['n'] += 1
            turn = TURN['n'] if is_main else 0

        msgs = req.get('messages') or []
        LOG.write(f"\n===== POST #{turn} {self.path} len={n} stream={req.get('stream')} "
                  f"model={req.get('model')} msgs={len(msgs)} tools={len(tools)} "
                  f"{'MAIN#%d' % turn if is_main else 'aux'} =====\n")
        # 完整 dump 最後 4 則, 看 client 把壞掉那一輪的殘骸怎麼帶回來
        for mi, mm in enumerate(msgs[-4:]):
            cc = mm.get('content')
            role = mm.get('role')
            if isinstance(cc, list):
                for b in cc:
                    t = b.get('type')
                    if t == 'tool_use':
                        LOG.write(f"   [{role}] TOOL_USE id={b.get('id')} name={b.get('name')} "
                                  f"input={json.dumps(b.get('input'))[:300]}\n")
                    elif t == 'tool_result':
                        LOG.write(f"   [{role}] TOOL_RESULT id={b.get('tool_use_id')} "
                                  f"is_error={b.get('is_error')} content={json.dumps(b.get('content'))[:300]}\n")
                    elif t == 'text':
                        LOG.write(f"   [{role}] text={b.get('text', '')[:300]!r}\n")
                    else:
                        LOG.write(f"   [{role}] {t}: {json.dumps(b)[:300]}\n")
            else:
                LOG.write(f"   [{role}] str={str(cc)[:300]!r}\n")
        LOG.flush()

        if not req.get('stream'):
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({
                "id": "msg_1", "type": "message", "role": "assistant",
                "model": req.get("model", "claude-opus-5"),
                "content": [{"type": "text", "text": "ok"}],
                "stop_reason": "end_turn",
                "usage": {"input_tokens": 10, "output_tokens": 5}}).encode())
            return

        self.send_response(200)
        self.send_header('Content-Type', 'text/event-stream')
        self.send_header('Cache-Control', 'no-cache')
        self.end_headers()
        w = self.wfile

        def start(msg_id):
            w.write(sse("message_start", {"type": "message_start", "message": {
                "id": msg_id, "type": "message", "role": "assistant",
                "model": req.get("model", "claude-opus-5"), "content": [],
                "stop_reason": None, "stop_sequence": None,
                "usage": {"input_tokens": 10, "output_tokens": 1}}}))

        def text_block(idx, s):
            w.write(sse("content_block_start", {"type": "content_block_start", "index": idx,
                                                "content_block": {"type": "text", "text": ""}}))
            w.write(sse("content_block_delta", {"type": "content_block_delta", "index": idx,
                                                "delta": {"type": "text_delta", "text": s}}))
            w.write(sse("content_block_stop", {"type": "content_block_stop", "index": idx}))

        def finish(stop_reason):
            w.write(sse("message_delta", {"type": "message_delta",
                                          "delta": {"stop_reason": stop_reason, "stop_sequence": None},
                                          "usage": {"output_tokens": 40}}))
            w.write(sse("message_stop", {"type": "message_stop"}))
            w.flush()

        # 非主對話, 或主對話第二輪起：正常結束，避免無限迴圈
        if not is_main or turn > 1:
            LOG.write(f"   >>> turn {turn}: normal end_turn reply\n")
            LOG.flush()
            start("msg_normal")
            text_block(0, "acknowledged")
            finish("end_turn")
            return

        LOG.write(f"   >>> turn 1: MODE={MODE}\n")
        LOG.flush()
        start("msg_probe")

        if MODE == 'dropblock':
            # D1: 宣告要用工具, 但 tool_use block 整個不存在
            text_block(0, "I'll run that command for you.")
            finish("tool_use")

        elif MODE == 'halfblock':
            # D2: block 開了就消失 — 無 delta, 無 content_block_stop
            text_block(0, "Running it now.")
            w.write(sse("content_block_start", {"type": "content_block_start", "index": 1,
                                                "content_block": {"type": "tool_use", "id": "toolu_probeD2",
                                                                  "name": "Bash", "input": {}}}))
            w.flush()
            finish("tool_use")

        elif MODE == 'emptyblock':
            # D3: 結構完整但零參數
            text_block(0, "Running it now.")
            w.write(sse("content_block_start", {"type": "content_block_start", "index": 1,
                                                "content_block": {"type": "tool_use", "id": "toolu_probeD3",
                                                                  "name": "Bash", "input": {}}}))
            w.write(sse("content_block_stop", {"type": "content_block_stop", "index": 1}))
            finish("tool_use")

        elif MODE == 'silentdrop':
            # D4: 模型在文字裡宣告要用工具, 但零 tool_use block 且 stop_reason=end_turn
            #     協定上完全合法 → client 無從偵測. 最接近「說要做但什麼都沒發生」的真實症狀
            text_block(0, "I'll run `echo hello` for you now.")
            finish("end_turn")

        elif MODE == 'partialdrop':
            # D5: 宣告三個工具呼叫, 只送出第一個; stop_reason=tool_use (合法, 因為確實有 block)
            text_block(0, "I'll run three commands: echo a, echo b, echo c.")
            w.write(sse("content_block_start", {"type": "content_block_start", "index": 1,
                                                "content_block": {"type": "tool_use", "id": "toolu_probeD5",
                                                                  "name": "Bash", "input": {}}}))
            for dl in ['{"comm', 'and":"echo a","des', 'cription":"first"}']:
                w.write(sse("content_block_delta", {"type": "content_block_delta", "index": 1,
                                                    "delta": {"type": "input_json_delta", "partial_json": dl}}))
            w.write(sse("content_block_stop", {"type": "content_block_stop", "index": 1}))
            finish("tool_use")

        else:
            text_block(0, f"unknown PROBE_MODE={MODE}")
            finish("end_turn")


if __name__ == '__main__':
    port = int(sys.argv[1])
    HTTPServer(('127.0.0.1', port), H).serve_forever()
