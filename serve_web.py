"""Local development server; Bluetooth stays in Chrome, not this process."""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit
import json
import mimetypes
import threading

ROOT = Path(__file__).resolve().parent
WEB = ROOT / "web"
PORT = 8974
ORIGIN = f"http://127.0.0.1:{PORT}"
LOCK = threading.Lock()


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def do_GET(self):
        if self.headers.get("Host") != f"127.0.0.1:{PORT}":
            self.send_error(403)
            return
        path = urlsplit(self.path).path
        target = (WEB / ("index.html" if path == "/" else path.lstrip("/"))).resolve()
        if WEB not in target.parents or not target.is_file():
            self.send_error(404)
            return
        body = target.read_bytes()
        content_type = mimetypes.guess_type(target.name)[0] or "application/octet-stream"
        self.send_response(200)
        self.send_header("Content-Type", content_type + "; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Security-Policy", "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; connect-src 'self'; object-src 'none'; base-uri 'none'; frame-ancestors 'none'")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self):
        if (self.path != "/api/evidence" or self.headers.get("Origin") != ORIGIN
                or self.headers.get("Host") != f"127.0.0.1:{PORT}"):
            self.send_error(403)
            return
        try:
            count = int(self.headers.get("Content-Length", "0"))
            if not 0 < count <= 32768:
                raise ValueError("Invalid result size")
            item = json.loads(self.rfile.read(count))
            if not isinstance(item, dict) or not isinstance(item.get("event"), str):
                raise ValueError("Invalid result")
            target = ROOT / "docs/heymelody/evidence/feature-validation-results.jsonl"
            with LOCK, target.open("a") as output:
                output.write(json.dumps(item) + "\n")
            print(item["event"], flush=True)
        except (ValueError, TypeError):
            self.send_error(400)
            return
        self.send_response(204)
        self.end_headers()


if __name__ == "__main__":
    print(f"Buds Web: {ORIGIN}", flush=True)
    ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
