#!/usr/bin/env python3
"""Minimal reference backend for the VPS Monitor iOS app.

Standard library only. Run it on the Linux server you want to monitor, ideally
behind a TLS-terminating reverse proxy (nginx, Caddy, ...).

Endpoints (the base path is configurable with VPS_STATUS_PATH):
  GET /api/status          -> current snapshot (VPSStatusResponse)
  GET /api/status/history  -> list of samples (VPSHistoricalSample[])

Environment variables:
  VPS_BIND             listen address           (default 127.0.0.1)
  VPS_PORT             listen port              (default 8787)
  VPS_STATUS_PATH      status path              (default /api/status)
  VPS_SERVICES         comma-separated systemd units to report, e.g. "nginx,postgresql"
  VPS_HMAC_SECRET      shared secret; when set, requests must be signed
  VPS_PUBLIC_BASE_URL  public origin the app uses, e.g. https://vps.example.com
                       (needed for signature checks behind a reverse proxy)
  VPS_SAMPLE_SECONDS   history sampling interval (default 300)
  VPS_HISTORY_SIZE     samples kept in memory   (default 288, i.e. 24 h at 5 min)
"""

import base64
import hashlib
import hmac
import json
import os
import shutil
import subprocess
import threading
import time
from collections import deque
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

BIND = os.environ.get("VPS_BIND", "127.0.0.1")
PORT = int(os.environ.get("VPS_PORT", "8787"))
STATUS_PATH = os.environ.get("VPS_STATUS_PATH", "/api/status").rstrip("/")
SERVICES = [s.strip() for s in os.environ.get("VPS_SERVICES", "").split(",") if s.strip()]
SECRET = os.environ.get("VPS_HMAC_SECRET", "")
PUBLIC_BASE_URL = os.environ.get("VPS_PUBLIC_BASE_URL", "").rstrip("/")
SAMPLE_SECONDS = int(os.environ.get("VPS_SAMPLE_SECONDS", "300"))
HISTORY = deque(maxlen=int(os.environ.get("VPS_HISTORY_SIZE", "288")))
MAX_CLOCK_SKEW = 300  # seconds


def iso_now():
    # No fractional seconds: Swift's JSONDecoder .iso8601 strategy rejects them.
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _cpu_times():
    with open("/proc/stat") as f:
        fields = [float(x) for x in f.readline().split()[1:]]
    idle = fields[3] + (fields[4] if len(fields) > 4 else 0.0)
    return idle, sum(fields)


def cpu_usage(interval=0.25):
    try:
        idle1, total1 = _cpu_times()
        time.sleep(interval)
        idle2, total2 = _cpu_times()
        total = total2 - total1
        return round(100.0 * (1.0 - (idle2 - idle1) / total), 1) if total > 0 else 0.0
    except OSError:
        return 0.0


def memory_usage():
    try:
        info = {}
        with open("/proc/meminfo") as f:
            for line in f:
                key, value = line.split(":", 1)
                info[key] = float(value.split()[0])
        total = info["MemTotal"]
        available = info.get("MemAvailable", info.get("MemFree", 0.0))
        return round(100.0 * (total - available) / total, 1)
    except (OSError, KeyError, ZeroDivisionError):
        return 0.0


def disk_usage(path="/"):
    usage = shutil.disk_usage(path)
    return round(100.0 * usage.used / usage.total, 1)


def uptime_text():
    try:
        with open("/proc/uptime") as f:
            seconds = int(float(f.read().split()[0]))
    except OSError:
        return "unknown"
    days, rem = divmod(seconds, 86400)
    hours, rem = divmod(rem, 3600)
    minutes = rem // 60
    if days:
        return f"{days}d {hours}h"
    if hours:
        return f"{hours}h {minutes}m"
    return f"{minutes}m"


def load_average():
    try:
        return [round(x, 2) for x in os.getloadavg()]
    except OSError:
        return [0.0, 0.0, 0.0]


def service_info(name):
    """Report a systemd unit. cpu = CPU seconds consumed, memory = MB in use."""
    try:
        state = subprocess.run(["systemctl", "is-active", name], capture_output=True, text=True, timeout=5).stdout.strip()
        props = subprocess.run(["systemctl", "show", name, "-p", "MemoryCurrent", "-p", "CPUUsageNSec"],
                               capture_output=True, text=True, timeout=5).stdout
    except (OSError, subprocess.TimeoutExpired):
        return {"name": name, "status": "unknown", "cpu": 0.0, "memory": 0.0}
    values = dict(line.split("=", 1) for line in props.splitlines() if "=" in line)

    def number(key, scale):
        try:
            return round(float(values.get(key, "")) / scale, 1)
        except ValueError:
            return 0.0

    return {
        "name": name,
        "status": "running" if state == "active" else (state or "unknown"),
        "cpu": number("CPUUsageNSec", 1e9),
        "memory": number("MemoryCurrent", 1024 * 1024),
    }


def snapshot():
    services = [service_info(name) for name in SERVICES]
    healthy = all(s["status"] == "running" for s in services)
    return {
        "status": "ok" if healthy else "degraded",
        "timestamp": iso_now(),
        "systemSummary": {
            "cpuUsage": cpu_usage(),
            "memoryUsage": memory_usage(),
            "diskUsage": disk_usage(),
            "uptime": uptime_text(),
            "load": load_average(),
        },
        "services": services,
    }


def sampler():
    while True:
        HISTORY.appendleft({
            "timestamp": iso_now(),
            "cpuUsage": cpu_usage(),
            "memoryUsage": memory_usage(),
            "diskUsage": disk_usage(),
        })
        time.sleep(SAMPLE_SECONDS)


class Handler(BaseHTTPRequestHandler):
    server_version = "VPSMonitorReference/1.0"

    def _send(self, code, payload):
        body = json.dumps(payload).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def _authorized(self):
        if not SECRET:
            return True
        timestamp = self.headers.get("X-Request-Timestamp", "")
        signature = self.headers.get("X-Request-Signature", "")
        try:
            sent = datetime.strptime(timestamp, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
        except ValueError:
            return False
        if abs((datetime.now(timezone.utc) - sent).total_seconds()) > MAX_CLOCK_SKEW:
            return False
        base = PUBLIC_BASE_URL or f"http://{self.headers.get('Host', '')}"
        payload = f"GET{base}{self.path}{timestamp}".encode()
        expected = base64.b64encode(hmac.new(SECRET.encode(), payload, hashlib.sha256).digest()).decode()
        return hmac.compare_digest(expected, signature)

    def do_GET(self):
        path = self.path.split("?", 1)[0].rstrip("/")
        if path not in (STATUS_PATH, STATUS_PATH + "/history"):
            return self._send(404, {"error": "not found"})
        if not self._authorized():
            return self._send(401, {"error": "invalid or missing signature"})
        if path == STATUS_PATH:
            return self._send(200, snapshot())
        return self._send(200, list(HISTORY))


def main():
    threading.Thread(target=sampler, daemon=True).start()
    print(f"VPS Monitor reference server on http://{BIND}:{PORT}{STATUS_PATH}"
          f" (signing {'required' if SECRET else 'disabled'})")
    ThreadingHTTPServer((BIND, PORT), Handler).serve_forever()


if __name__ == "__main__":
    main()
