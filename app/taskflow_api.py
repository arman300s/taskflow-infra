#!/usr/bin/env python3
"""TaskFlow API - tiny task manager service (Python standard library only).

GET  /health        -> {"status": "ok"}
GET  /tasks         -> list of tasks
POST /tasks {title} -> create a task
"""
import json
import os
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

PORT = int(os.environ.get("APP_PORT", "8000"))
DATA_FILE = os.environ.get("DATA_FILE", "/var/lib/taskflow/tasks.json")
VERSION = "1.1.0"
lock = threading.Lock()


def load():
    try:
        with open(DATA_FILE) as f:
            return json.load(f)
    except FileNotFoundError:
        return []


def save(tasks):
    tmp = DATA_FILE + ".tmp"
    with open(tmp, "w") as f:
        json.dump(tasks, f, indent=2)
    os.replace(tmp, DATA_FILE)


class Handler(BaseHTTPRequestHandler):
    def reply(self, code, body):
        data = json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if self.path in ("/", "/health"):
            self.reply(200, {"status": "ok", "version": VERSION})
        elif self.path == "/tasks":
            self.reply(200, load())
        else:
            self.reply(404, {"error": "not found"})

    def do_POST(self):
        if self.path != "/tasks":
            return self.reply(404, {"error": "not found"})
        try:
            body = json.loads(self.rfile.read(int(self.headers.get("Content-Length", 0))))
            title = str(body["title"]).strip()
            assert title
        except Exception:
            return self.reply(422, {"error": "field 'title' is required"})
        with lock:
            tasks = load()
            task = {"id": len(tasks) + 1, "title": title, "done": False}
            tasks.append(task)
            save(tasks)
        self.reply(201, task)


if __name__ == "__main__":
    print(f"TaskFlow API v{VERSION} listening on :{PORT}, data={DATA_FILE}", flush=True)
    ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
