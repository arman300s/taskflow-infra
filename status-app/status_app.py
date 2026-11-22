#!/usr/bin/env python3
"""taskflow-status - status page of the TaskFlow system (Python standard library only).

GET /            -> HTML page with the state of the API and of every server
GET /api/status  -> the same as JSON
GET /health      -> {"status": "ok"}   (used by the Docker HEALTHCHECK)
"""
import json
import os
import time
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

PORT = int(os.environ.get("PORT", "8080"))
API_URL = os.environ.get("API_URL", "http://tf-app:8000")
NODES = [n for n in os.environ.get("NODES", "tf-web,tf-app,tf-db").split(",") if n]
VERSION = "1.0.0"
TIMEOUT = 3


def fetch(url):
    with urllib.request.urlopen(url, timeout=TIMEOUT) as r:
        return r.read().decode()


def metrics(node):
    """A few numbers from node_exporter on <node>:9100."""
    want = {"node_load1": None, "node_memory_MemAvailable_bytes": None,
            "node_memory_MemTotal_bytes": None, "node_boot_time_seconds": None}
    try:
        for line in fetch(f"http://{node}:9100/metrics").splitlines():
            name, _, value = line.partition(" ")
            if name in want:
                want[name] = float(value)
        mem = 100 * (1 - want["node_memory_MemAvailable_bytes"] / want["node_memory_MemTotal_bytes"])
        return {"node": node, "up": True, "load1": round(want["node_load1"], 2),
                "mem_used_pct": round(mem, 1),
                "uptime_h": round((time.time() - want["node_boot_time_seconds"]) / 3600, 1)}
    except Exception as e:  # node down or port closed
        return {"node": node, "up": False, "error": type(e).__name__}


def status():
    try:
        api = json.loads(fetch(f"{API_URL}/health"))
        tasks = len(json.loads(fetch(f"{API_URL}/tasks")))
        api_state = {"up": True, "version": api.get("version"), "tasks": tasks}
    except Exception as e:
        api_state = {"up": False, "error": type(e).__name__}
    return {"service": "taskflow-status", "version": VERSION, "time": time.strftime("%Y-%m-%d %H:%M:%S"),
            "api": api_state, "nodes": [metrics(n) for n in NODES]}


def page(s):
    dot = lambda ok: f'<span style="color:{"#16a34a" if ok else "#dc2626"}">&#9679;</span>'
    rows = "".join(
        f"<tr><td>{dot(n['up'])} {n['node']}</td>"
        + (f"<td>{n['load1']}</td><td>{n['mem_used_pct']} %</td><td>{n['uptime_h']} h</td>" if n["up"]
           else f"<td colspan=3>down ({n['error']})</td>") + "</tr>"
        for n in s["nodes"])
    api = s["api"]
    api_txt = f"v{api['version']}, {api['tasks']} tasks" if api["up"] else f"down ({api['error']})"
    return f"""<!doctype html><html><head><meta charset="utf-8"><title>TaskFlow status</title>
<meta http-equiv="refresh" content="10"></head>
<body style="font-family:sans-serif;max-width:640px;margin:40px auto">
<h1>TaskFlow status</h1><p>{dot(api['up'])} <b>API</b>: {api_txt}</p>
<table border=1 cellpadding=6 style="border-collapse:collapse">
<tr><th>Server</th><th>Load (1 min)</th><th>Memory used</th><th>Uptime</th></tr>{rows}</table>
<p><small>taskflow-status v{VERSION} (container) &middot; {s['time']} &middot; refreshes every 10 s</small></p>
</body></html>"""


class Handler(BaseHTTPRequestHandler):
    def send(self, code, body, ctype):
        data = body.encode()
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if self.path == "/health":
            self.send(200, json.dumps({"status": "ok", "version": VERSION}), "application/json")
        elif self.path == "/api/status":
            self.send(200, json.dumps(status()), "application/json")
        elif self.path == "/":
            self.send(200, page(status()), "text/html; charset=utf-8")
        else:
            self.send(404, json.dumps({"error": "not found"}), "application/json")

    def log_message(self, fmt, *args):  # one short line per request on stdout (docker logs)
        print(f"{self.address_string()} {fmt % args}", flush=True)


if __name__ == "__main__":
    print(f"taskflow-status v{VERSION} on :{PORT}, api={API_URL}, nodes={NODES}", flush=True)
    ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
