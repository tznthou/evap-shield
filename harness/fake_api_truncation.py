import json, sys, threading
from http.server import BaseHTTPRequestHandler, HTTPServer

LOG = open(sys.argv[2] if len(sys.argv) > 2 else '/tmp/fake_api.log', 'w')
CUT_AT = int(sys.argv[3]) if len(sys.argv) > 3 else 3   # 送幾個 delta 後切斷

TOOL_ARGS = json.dumps({"command": "echo " + "A"*180 + " done", "description": "probe"})
# 切成 delta（模擬 model token 分塊）
CH = 20
DELTAS = [TOOL_ARGS[i:i+CH] for i in range(0, len(TOOL_ARGS), CH)]

def sse(ev, obj):
    return f"event: {ev}\ndata: {json.dumps(obj)}\n\n".encode()

class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def _log(self, tag, extra=""):
        LOG.write(f"{tag} {self.path} {extra}\n"); LOG.flush()

    def do_GET(self):
        self._log("GET")
        self.send_response(200); self.send_header('Content-Type','application/json'); self.end_headers()
        self.wfile.write(b'{}')

    def do_POST(self):
        n = int(self.headers.get('Content-Length') or 0)
        body = self.rfile.read(n) if n else b''
        self._log("POST", f"len={n}")
        try: req = json.loads(body)
        except Exception: req = {}
        msgs = req.get('messages') or []
        LOG.write(f"   stream={req.get('stream')} model={req.get('model')} msgs={len(msgs)}\n")
        for mi, mm in enumerate(msgs[-3:]):
            cc = mm.get('content')
            if isinstance(cc, list):
                for b in cc:
                    t = b.get('type')
                    if t == 'tool_use':
                        LOG.write(f"     [msg-{mi} role={mm.get('role')}] TOOL_USE name={b.get('name')} input={json.dumps(b.get('input'))[:160]}\n")
                    elif t == 'text':
                        LOG.write(f"     [msg-{mi} role={mm.get('role')}] text={b.get('text','')[:100]!r}\n")
                    else:
                        LOG.write(f"     [msg-{mi} role={mm.get('role')}] {t}\n")
            else:
                LOG.write(f"     [msg-{mi} role={mm.get('role')}] str={str(cc)[:100]!r}\n")
        LOG.flush()

        if 'count_tokens' in self.path:
            self.send_response(200); self.send_header('Content-Type','application/json'); self.end_headers()
            self.wfile.write(b'{"input_tokens":10}'); return

        if not req.get('stream'):
            self.send_response(200); self.send_header('Content-Type','application/json'); self.end_headers()
            self.wfile.write(json.dumps({"id":"msg_1","type":"message","role":"assistant",
                "model":req.get("model","claude-opus-5"),"content":[{"type":"text","text":"ok"}],
                "stop_reason":"end_turn","usage":{"input_tokens":10,"output_tokens":5}}).encode()); return

        self.send_response(200)
        self.send_header('Content-Type','text/event-stream')
        self.send_header('Cache-Control','no-cache')
        self.end_headers()
        w = self.wfile
        w.write(sse("message_start", {"type":"message_start","message":{"id":"msg_probe","type":"message",
            "role":"assistant","model":req.get("model","claude-opus-5"),"content":[],"stop_reason":None,
            "stop_sequence":None,"usage":{"input_tokens":10,"output_tokens":1}}}))
        w.write(sse("content_block_start", {"type":"content_block_start","index":0,
            "content_block":{"type":"tool_use","id":"toolu_probe1","name":"Bash","input":{}}}))
        w.flush()
        for i, dl in enumerate(DELTAS):
            if i >= CUT_AT:
                import os, time
                mode = os.environ.get('PROBE_MODE','cut')
                LOG.write(f"   >>> {mode.upper()} after {i} deltas (buffer={''.join(DELTAS[:i])!r})\n"); LOG.flush()
                if mode == 'hang':
                    time.sleep(300)     # 掛住，讓 client 有時間主動 abort
                if mode == 'truncate':
                    # stream 正常收尾，但 buffer 裡是截斷的 JSON（= max_tokens 截斷）
                    w.write(sse("content_block_stop", {"type":"content_block_stop","index":0}))
                    w.write(sse("message_delta", {"type":"message_delta",
                        "delta":{"stop_reason":"max_tokens","stop_sequence":None},
                        "usage":{"output_tokens":64}}))
                    w.write(sse("message_stop", {"type":"message_stop"}))
                    w.flush()
                    return
                try: self.connection.close()
                except Exception: pass
                return
            w.write(sse("content_block_delta", {"type":"content_block_delta","index":0,
                "delta":{"type":"input_json_delta","partial_json":dl}}))
            w.flush()

if __name__ == '__main__':
    port = int(sys.argv[1])
    HTTPServer(('127.0.0.1', port), H).serve_forever()
