#!/usr/bin/env python3
"""
Local static server for the WebGL harness pages.

Serves a directory on 127.0.0.1 and also accepts `PUT /upload.bin`, which
writes the request body into that directory. A harness page uses this to hand
rendered pixels back for icons and measurements, so no base64 has to travel
through the browser tools.

Usage:
    python3 serve.py <port> <directory>

Run it through the browser pane's launch configuration (.claude/launch.json,
which is gitignored because it holds local paths), not from Bash.
"""
import http.server
import os
import sys

PORT = int(sys.argv[1])
ROOT = os.path.abspath(sys.argv[2])


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **k):
        super().__init__(*a, directory=ROOT, **k)

    def do_PUT(self):
        if self.path != "/upload.bin":
            self.send_error(403)
            return
        n = int(self.headers.get("Content-Length", 0))
        with open(os.path.join(ROOT, "upload.bin"), "wb") as f:
            f.write(self.rfile.read(n))
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"ok")


http.server.ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
