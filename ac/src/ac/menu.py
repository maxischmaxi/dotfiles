"""Interaktives Menü (Rechtsklick aus Waybar) via rofi/wofi/fuzzel."""

from __future__ import annotations

import os
import shlex
import shutil
import subprocess
from typing import Any

from . import device, logic


def _launcher() -> list[str] | None:
    override = os.environ.get("AC_MENU")
    if override:
        return shlex.split(override)
    candidates = (
        ["fuzzel", "--dmenu", "--prompt", "AC  "],
        ["wofi", "--dmenu", "--prompt", "AC"],
        ["rofi", "-dmenu", "-i", "-p", "AC"],
    )
    for cmd in candidates:
        if shutil.which(cmd[0]):
            return cmd
    return None


def _pick(entries: list[tuple[str, str]]) -> str | None:
    cmd = _launcher()
    if not cmd:
        raise device.ACError(
            "Kein Launcher gefunden (rofi/wofi/fuzzel). Alternativ $AC_MENU setzen."
        )
    labels = "\n".join(label for label, _ in entries)
    proc = subprocess.run(cmd, input=labels, capture_output=True, text=True)
    sel = proc.stdout.strip()
    if not sel:
        return None
    for label, key in entries:
        if label == sel:
            return key
    return None


def _apply(key: str, dev: dict[str, Any], state: dict[str, Any]) -> None:
    kind, _, arg = key.partition(":")
    if kind == "power":
        device.set_power(arg == "on", dev)
    elif kind == "mode":
        # Aus dem Aus heraus erst einschalten, dann Modus setzen.
        if not state.get("power"):
            device.set_power(True, dev)
        device.set_mode(arg, dev)
    elif kind == "fan":
        device.set_fan(arg, dev)
    elif kind == "temp":
        device.set_temp(int(arg), dev)


def run_menu() -> None:
    dev = device._selected_dev()
    state = device.read_state(fast=True)

    key = _pick(logic.top_entries(state, dev))
    if key is None or key == "refresh":
        return

    if key.startswith("menu:"):
        kind = key.split(":", 1)[1]
        key = _pick(logic.submenu_entries(kind, state, dev))
        if key is None:
            return

    _apply(key, dev, state)
