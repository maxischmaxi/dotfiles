"""Tuya-Anbindung: Cloud-Sync, LAN-Scan und lokale Steuerung."""

from __future__ import annotations

import contextlib
import fcntl
import time
from typing import Any

import tinytuya

from . import config, logic


class ACError(Exception):
    """Erwartbarer Fehler mit benutzerfreundlicher Meldung."""


@contextlib.contextmanager
def _device_lock(timeout: float = 4.0):
    """Serialisiert LAN-Zugriffe über alle ac-Prozesse hinweg.

    Tuya erlaubt nur eine TCP-Verbindung gleichzeitig — ohne diesen Lock
    würden Waybar-Poll und Klick kollidieren. Best-effort: kann der Lock
    nicht rechtzeitig geholt werden, läuft der Aufruf trotzdem (und scheitert
    dann sauber an der belegten Verbindung).
    """
    config.config_home().mkdir(parents=True, exist_ok=True)
    handle = open(config.config_home() / ".device.lock", "w")
    acquired = False
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        try:
            fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
            acquired = True
            break
        except OSError:
            time.sleep(0.1)
    try:
        yield
    finally:
        if acquired:
            fcntl.flock(handle, fcntl.LOCK_UN)
        handle.close()


def _cloud() -> tinytuya.Cloud:
    creds = config.credentials()
    if not creds["key"] or not creds["secret"]:
        raise ACError(
            "Keine Cloud-Credentials gefunden. Lege eine .env mit "
            "TUYA_API_KEY / TUYA_API_SECRET / TUYA_API_REGION an (siehe .env.example)."
        )
    return tinytuya.Cloud(
        apiRegion=creds["region"],
        apiKey=creds["key"],
        apiSecret=creds["secret"],
    )


def cloud_sync() -> list[dict[str, Any]]:
    """Holt alle Geräte inkl. Local Key aus der Tuya-Cloud und merged sie in den Store.

    Die Cloud kennt nur die öffentliche IP — die lokale IP fürs LAN-Steuern
    liefert erst `lan_scan()`.
    """
    result = _cloud().getdevices(verbose=False)
    if isinstance(result, dict) and result.get("Error"):
        raise ACError(f"Cloud-Fehler: {result.get('Error')} — {result.get('Payload')}")

    store = config.load_store()
    devices = store.setdefault("devices", {})
    for d in result:
        dev_id = d.get("id")
        if not dev_id:
            continue
        entry = devices.get(dev_id, {})
        entry.update(
            {
                "id": dev_id,
                "name": d.get("name", entry.get("name", dev_id)),
                "key": d.get("key", entry.get("key", "")),
                "category": d.get("category", entry.get("category", "")),
            }
        )
        # Protokoll-Version kommt zuverlässig nur aus dem LAN-Scan.
        entry.setdefault("version", "3.3")
        config.ensure_device_defaults(entry)
        devices[dev_id] = entry

    if not store.get("selected") and devices:
        store["selected"] = next(iter(devices))
    config.save_store(store)
    return list(devices.values())


def lan_scan(maxretry: int | None = None, force: bool = False) -> dict[str, str]:
    """LAN-Scan: findet lokale IP + Protokollversion und schreibt sie in den Store.

    Gibt {device_id: ip} der zugeordneten Geräte zurück.
    """
    found = tinytuya.deviceScan(verbose=False, maxretry=maxretry, forcescan=force)
    store = config.load_store()
    devices = store.get("devices", {})
    matched: dict[str, str] = {}
    for ip, info in found.items():
        gwid = info.get("gwId") or info.get("id")
        real_ip = info.get("ip", ip)
        if gwid and gwid in devices:
            devices[gwid]["ip"] = real_ip
            if info.get("version"):
                devices[gwid]["version"] = str(info["version"])
            matched[gwid] = real_ip
    config.save_store(store)
    return matched


def connect(dev: dict[str, Any] | None = None, fast: bool = False) -> tinytuya.Device:
    dev = dev or config.selected_device()
    if not dev:
        raise ACError("Kein Gerät ausgewählt. Erst `ac sync` ausführen.")
    if not dev.get("key"):
        raise ACError("Kein Local Key vorhanden. Führe `ac sync` aus.")
    if not dev.get("ip"):
        raise ACError(
            f"Keine lokale IP für '{dev.get('name')}'. Führe `ac scan` im selben WLAN aus."
        )
    try:
        version = float(str(dev.get("version", "3.3")) or "3.3")
    except ValueError:
        version = 3.3
    # fast=True: schnelles Aufgeben statt langer Retries — wichtig für Waybar,
    # damit der Balken bei offline-Gerät nicht blockiert.
    extra: dict[str, Any] = (
        {"connection_timeout": 2, "connection_retry_limit": 1, "connection_retry_delay": 1}
        if fast
        else {}
    )
    return tinytuya.Device(
        dev["id"], address=dev["ip"], local_key=dev["key"], version=version, **extra
    )


def status(dev: dict[str, Any] | None = None) -> dict[str, Any]:
    d = connect(dev)
    with _device_lock():
        data = d.status()
    if isinstance(data, dict) and data.get("Error"):
        raise ACError(f"Geräte-Fehler: {data.get('Error')} — {data.get('Payload')}")
    return data


def set_dp(index: int, value: Any, dev: dict[str, Any] | None = None) -> dict[str, Any]:
    d = connect(dev)
    with _device_lock():
        data = d.set_value(index, value)
    if isinstance(data, dict) and data.get("Error"):
        raise ACError(f"Geräte-Fehler: {data.get('Error')} — {data.get('Payload')}")
    return data


# --------------------------------------------------------------------------- #
# Interpretierter Zustand
# --------------------------------------------------------------------------- #
def _selected_dev() -> dict[str, Any]:
    dev = config.selected_device()
    if not dev:
        raise ACError("Kein Gerät ausgewählt. Erst `ac sync` ausführen.")
    return config.ensure_device_defaults(dev)


def read_state(fast: bool = False) -> dict[str, Any]:
    """Liest den Zustand und interpretiert ihn anhand des DP-Mappings.

    Bei Verbindungsfehlern: {"online": False, ...} statt Exception, damit
    Anzeige-Pfade (Waybar) robust bleiben.
    """
    dev = _selected_dev()
    d = connect(dev, fast=fast)
    try:
        with _device_lock():
            data = d.status()
    except Exception as e:  # noqa: BLE001 — bewusst breit für die Anzeige
        return {"online": False, "device": dev, "error": str(e)}
    if not isinstance(data, dict) or data.get("Error") or "dps" not in data:
        err = data.get("Error") if isinstance(data, dict) else "keine Daten"
        return {"online": False, "device": dev, "error": err}

    dps = data["dps"]
    m = dev["dps"]

    def g(field: str) -> Any:
        return dps.get(str(m.get(field)))

    return {
        "online": True,
        "device": dev,
        "power": bool(g("power")),
        "temp_set": g("temp_set"),
        "temp_current": g("temp_current"),
        "mode_raw": g("mode"),
        "mode": logic.reverse_lookup(g("mode"), dev["mode_values"]),
        "fan_raw": g("fan"),
        "fan": logic.reverse_lookup(g("fan"), dev["fan_values"]),
        "raw": dps,
    }


# --------------------------------------------------------------------------- #
# Steuerung (absolut + relativ)
# --------------------------------------------------------------------------- #
def set_field(field: str, value: Any, dev: dict[str, Any] | None = None) -> dict[str, Any]:
    dev = dev or _selected_dev()
    dp = dev["dps"].get(field)
    if dp is None:
        raise ACError(f"Kein DP für '{field}' gemappt (siehe `ac map show`).")
    return set_dp(int(dp), value, dev)


def set_power(on: bool, dev: dict[str, Any] | None = None) -> bool:
    set_field("power", bool(on), dev)
    return bool(on)


def toggle(dev: dict[str, Any] | None = None) -> bool:
    dev = dev or _selected_dev()
    st = read_state()
    if not st.get("online"):
        raise ACError(f"Gerät nicht erreichbar: {st.get('error')}")
    return set_power(not st["power"], dev)


def set_temp(value: int, dev: dict[str, Any] | None = None) -> int:
    dev = dev or _selected_dev()
    v = logic.clamp(int(value), dev["temp_min"], dev["temp_max"])
    set_field("temp_set", v, dev)
    return v


def step_temp(delta: int, dev: dict[str, Any] | None = None) -> int:
    dev = dev or _selected_dev()
    st = read_state()
    if st.get("temp_set") is None:
        raise ACError("Zieltemperatur unbekannt (Gerät offline?).")
    return set_temp(int(st["temp_set"]) + delta, dev)


def set_fan(name: str, dev: dict[str, Any] | None = None, raw: bool = False) -> str:
    dev = dev or _selected_dev()
    if raw:
        set_field("fan", name, dev)
        return name
    if name not in dev["fan_values"]:
        raise ACError(
            f"Unbekannte Lüfterstufe '{name}'. Verfügbar: {', '.join(dev['fan_values'])} (oder --raw)."
        )
    set_field("fan", dev["fan_values"][name], dev)
    return name


def step_fan(delta: int, dev: dict[str, Any] | None = None, wrap: bool = False) -> str:
    dev = dev or _selected_dev()
    st = read_state()
    order = [f for f in dev["fan_order"] if f in dev["fan_values"]]
    return set_fan(logic.step_in_list(st.get("fan"), order, delta, wrap=wrap), dev)


def set_mode(name: str, dev: dict[str, Any] | None = None, raw: bool = False) -> str:
    dev = dev or _selected_dev()
    if raw:
        set_field("mode", name, dev)
        return name
    if name not in dev["mode_values"]:
        raise ACError(
            f"Unbekannter Modus '{name}'. Verfügbar: {', '.join(dev['mode_values'])} (oder --raw)."
        )
    set_field("mode", dev["mode_values"][name], dev)
    return name


def next_mode(dev: dict[str, Any] | None = None) -> str:
    dev = dev or _selected_dev()
    st = read_state()
    order = [m for m in dev["mode_order"] if m in dev["mode_values"]]
    return set_mode(logic.step_in_list(st.get("mode"), order, 1, wrap=True), dev)


def do_scroll(direction: str, dev: dict[str, Any] | None = None) -> tuple[str, Any]:
    """Mode-abhängiges Scrollen: Temperatur (in temp_modes) sonst Lüfter."""
    dev = dev or _selected_dev()
    st = read_state()
    if not st.get("online"):
        raise ACError(f"Gerät nicht erreichbar: {st.get('error')}")
    kind, delta = logic.plan_scroll(st, direction, dev)
    if kind == "temp":
        return ("temp", set_temp(int(st["temp_set"]) + delta, dev))
    order = [f for f in dev["fan_order"] if f in dev["fan_values"]]
    return ("fan", set_fan(logic.step_in_list(st.get("fan"), order, delta, wrap=False), dev))
