"""Pure Domänenlogik — kein I/O, keine GUI. Damit voll unit-testbar.

Eingabe ist überall ein `state`-dict (siehe device.read_state) plus die
Geräte-Konfiguration `dev` (mit den Defaults aus config.ensure_device_defaults).
"""

from __future__ import annotations

from typing import Any


def reverse_lookup(value: Any, mapping: dict[str, str]) -> str | None:
    """Roher Geräte-Wert -> freundlicher Name (oder None)."""
    for name, raw in mapping.items():
        if str(raw) == str(value):
            return name
    return None


def clamp(value: int, lo: int, hi: int) -> int:
    return max(lo, min(hi, value))


def step_in_list(current: str | None, order: list[str], delta: int, wrap: bool = False) -> str:
    """Nächsten/vorherigen Eintrag in `order` bestimmen.

    wrap=False: an den Enden festklemmen (Scroll). wrap=True: umlaufen (Cycle).
    Ist `current` nicht in der Liste, am sinnvollen Ende einsteigen.
    """
    if not order:
        return current or ""
    if current in order:
        idx = order.index(current) + delta
    else:
        idx = 0 if delta >= 0 else len(order) - 1
        return order[idx]
    if wrap:
        return order[idx % len(order)]
    return order[clamp(idx, 0, len(order) - 1)]


def plan_scroll(state: dict[str, Any], direction: str, dev: dict[str, Any]) -> tuple[str, int]:
    """Entscheidet, was Scrollen tut: Temperatur (in temp_modes) oder Lüfter.

    Gibt ("temp", ±1) oder ("fan", ±1) zurück.
    """
    delta = 1 if direction == "up" else -1
    if state.get("power") and state.get("mode") in dev["temp_modes"]:
        return ("temp", delta)
    return ("fan", delta)


def mode_icon(mode: str | None, dev: dict[str, Any]) -> str:
    icons = dev["icons"]
    return icons.get(mode or "", icons.get("cool", "?"))


def format_waybar(state: dict[str, Any], dev: dict[str, Any]) -> dict[str, Any]:
    """State -> Waybar-JSON ({text, tooltip, class})."""
    icons = dev["icons"]
    if not state.get("online"):
        return {
            "text": icons["disconnected"],
            "tooltip": "AC: nicht erreichbar\n(SmartLife-App offen? Gerät im LAN?)",
            "class": "disconnected",
        }
    ist = state.get("temp_current")
    if not state.get("power"):
        return {
            "text": icons["off"],
            "tooltip": f"AC: aus · Ist {ist}°",
            "class": "off",
        }
    mode = state.get("mode") or state.get("mode_raw")
    fan = state.get("fan") or state.get("fan_raw")
    icon = mode_icon(mode, dev)
    if mode in dev["temp_modes"]:
        text = f"{icon} {state.get('temp_set')}°"
    else:
        text = f"{icon} {fan}"
    tooltip = (
        f"AC: {mode}\n"
        f"Ziel {state.get('temp_set')}° · Ist {ist}°\n"
        f"Lüfter {fan}\n"
        "Links: an/aus · Mitte: Lüfter · Rechts: Menü · Scroll: "
        + ("Temp" if mode in dev["temp_modes"] else "Lüfter")
    )
    css = mode if mode in ("cool", "heat", "dry", "fan", "auto") else "on"
    return {"text": text, "tooltip": tooltip, "class": css}


# --------------------------------------------------------------------------- #
# rofi-Menü: pure Erzeugung der Einträge. Format: list[(label, key)].
# keys: "power:on" | "power:off" | "mode:<name>" | "fan:<name>" |
#       "temp:<n>" | "menu:mode" | "menu:fan" | "menu:temp" | "refresh"
# --------------------------------------------------------------------------- #
def top_entries(state: dict[str, Any], dev: dict[str, Any]) -> list[tuple[str, str]]:
    icons = dev["icons"]
    if not state.get("online"):
        return [(f"{icons['disconnected']}  Gerät offline — erneut versuchen", "refresh")]

    if not state.get("power"):
        entries = [(f"{icons['power']}  Einschalten", "power:on")]
        for m in dev["mode_order"]:
            if m in dev["mode_values"]:
                entries.append((f"{mode_icon(m, dev)}  Einschalten · Modus {m}", f"mode:{m}"))
        return entries

    entries = [(f"{icons['power']}  Ausschalten", "power:off")]
    entries.append((f"{mode_icon(state.get('mode'), dev)}  Modus ▸  ({state.get('mode')})", "menu:mode"))
    entries.append((f"{icons['fan']}  Lüfter ▸  ({state.get('fan')})", "menu:fan"))
    if state.get("mode") in dev["temp_modes"]:
        entries.append((f"{icons['auto']}  Temperatur ▸  ({state.get('temp_set')}°)", "menu:temp"))
    return entries


def submenu_entries(kind: str, state: dict[str, Any], dev: dict[str, Any]) -> list[tuple[str, str]]:
    check = "  ✓"
    if kind == "mode":
        cur = state.get("mode")
        return [
            (f"{mode_icon(m, dev)}  {m}{check if m == cur else ''}", f"mode:{m}")
            for m in dev["mode_order"] if m in dev["mode_values"]
        ]
    if kind == "fan":
        cur = state.get("fan")
        return [
            (f"{dev['icons']['fan']}  {f}{check if f == cur else ''}", f"fan:{f}")
            for f in dev["fan_order"] if f in dev["fan_values"]
        ]
    if kind == "temp":
        cur = state.get("temp_set")
        return [
            (f"{t}°{check if t == cur else ''}", f"temp:{t}")
            for t in range(dev["temp_min"], dev["temp_max"] + 1)
        ]
    return []
