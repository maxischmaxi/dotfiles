#!/usr/bin/env python3
# Listens to Hyprland socket2. When a new google-chrome(-beta) window opens
# whose initial title starts with "Google Meet", float and pin it.
# Catches Google Meet's Document-Picture-in-Picture popout which otherwise
# gets auto-tiled.

import os, socket, subprocess, sys, time

sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
if not sig:
    sys.exit("HYPRLAND_INSTANCE_SIGNATURE not set")

LOG = open("/tmp/pip-autofloat.log", "w", buffering=1)
def log(msg): LOG.write(f"{time.strftime('%H:%M:%S')} {msg}\n")

log(f"starting, sig={sig}")

path = f"/run/user/{os.getuid()}/hypr/{sig}/.socket2.sock"
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.connect(path)
log(f"connected {path}")

buf = b""
while True:
    data = s.recv(4096)
    if not data:
        break
    buf += data
    while b"\n" in buf:
        raw, buf = buf.split(b"\n", 1)
        try:
            line = raw.decode()
        except UnicodeDecodeError:
            continue
        if not line.startswith("openwindow>>"):
            continue
        payload = line[len("openwindow>>"):]
        parts = payload.split(",", 3)
        if len(parts) < 4:
            continue
        addr, _ws, cls, title = parts
        log(f"openwindow addr=0x{addr} cls={cls!r} title={title!r}")
        # Google Meet titles use a non-breaking space (U+00A0) between
        # "Google" and "Meet", so normalize before matching.
        norm_title = title.replace("\xa0", " ")
        if cls in ("google-chrome", "google-chrome-beta") and norm_title.startswith("Google Meet"):
            target = f"address:0x{addr}"
            r1 = subprocess.run(["hyprctl", "dispatch", "setfloating", target],
                                capture_output=True, text=True)
            r2 = subprocess.run(["hyprctl", "dispatch", "pin", target],
                                capture_output=True, text=True)
            log(f"  -> MATCH; setfloating={r1.stdout.strip()!r}/{r1.stderr.strip()!r} pin={r2.stdout.strip()!r}/{r2.stderr.strip()!r}")
