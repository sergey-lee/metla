#!/usr/bin/env python3
"""Runs a sandboxed build against a test home folder and photographs every section.

The sandboxed app cannot run screencapture itself, so it prints "SHOT <window> <name>"
and this script takes the picture. usage: sandbox_check.py <Metla.app> <test home> <out> [app args…]"""
import os
import signal
import subprocess
import sys

app, home, out, *extra = sys.argv[1:]
os.makedirs(out, exist_ok=True)
binary = os.path.join(app, "Contents/MacOS/Metla")
process = subprocess.Popen(
    [binary, "--home", home, "--snapshot", out, "--assume-home-access", *extra],
    stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True,
)
try:
    for line in process.stdout:
        line = line.strip()
        if not line.startswith("SHOT "):
            continue
        _, window, name = line.split(" ", 2)
        target = os.path.join(out, name + ".png")
        subprocess.run(["/usr/sbin/screencapture", "-x", "-o", "-l", window, target], check=False)
        print(name, "ok" if os.path.exists(target) else "missing", flush=True)
    process.wait(timeout=30)
except subprocess.TimeoutExpired:
    process.send_signal(signal.SIGTERM)
