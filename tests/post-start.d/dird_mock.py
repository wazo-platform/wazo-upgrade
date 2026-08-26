#!/usr/bin/env python3
# Copyright 2026 The Wazo Authors  (see the AUTHORS file)
# SPDX-License-Identifier: GPL-3.0-or-later

"""Stand in for wazo-dird over a socket, so a script's own HTTP code runs.

The status route answers anything, as the scripts only use it to wait for
wazo-dird to come back. The reply to a POST is read from files on each
request, so a test can change it once this is already listening.

    dird_mock.py <port> <calls_file> <status_file> <body_file>
"""

import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

PORT, CALLS_FILE, STATUS_FILE, BODY_FILE = sys.argv[1:5]


class DirdHandler(BaseHTTPRequestHandler):
    def do_GET(self) -> None:
        self._reply(200, '{}')

    def do_POST(self) -> None:
        with open(CALLS_FILE, 'a') as f:
            f.write(self.path + '\n')

        with open(STATUS_FILE) as f:
            status = int(f.read())
        with open(BODY_FILE) as f:
            body = f.read()

        self._reply(status, body)

    def _reply(self, status: int, body: str) -> None:
        payload = body.encode()
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, *args: object) -> None:
        pass


if __name__ == '__main__':
    ThreadingHTTPServer(('127.0.0.1', int(PORT)), DirdHandler).serve_forever()
