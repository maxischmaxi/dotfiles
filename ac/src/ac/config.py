"""Konfiguration & Persistenz für ac.

Credentials kommen aus Umgebungsvariablen (optional via .env-Datei):
    TUYA_API_KEY, TUYA_API_SECRET, TUYA_API_REGION

Gerätedaten (inkl. Local Key) liegen in devices.json im Config-Verzeichnis.
"""

from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any

# Standard-DP-Mapping für Tuya-Klimaanlagen (Kategorie "kt").
# ACHTUNG: DP-Nummern UND Enum-Werte variieren je Modell. Mit `ac dps`
# die echten Werte auslesen und ggf. per `ac map set <feld> <dp>` anpassen.
DEFAULT_DPS: dict[str, int] = {
    "power": 1,         # bool  an/aus
    "temp_set": 2,      # int   Zieltemperatur
    "temp_current": 3,  # int   Ist-Temperatur (read-only)
    "mode": 4,          # enum  Betriebsmodus
    "fan": 5,           # enum  Lüfterstufe
}

# Mapping freundlicher Name -> roher Enum-Wert am Gerät.
DEFAULT_MODE_VALUES: dict[str, str] = {
    "auto": "auto",
    "cool": "cold",
    "heat": "hot",
    "dry": "wet",
    "fan": "wind",
}
DEFAULT_FAN_VALUES: dict[str, str] = {
    "auto": "auto",
    "low": "low",
    "mid": "mid",
    "high": "high",
}

# Reihenfolgen fürs Durchschalten (Scroll / Mittelklick / Mode-Cycle).
DEFAULT_FAN_ORDER: list[str] = ["auto", "low", "mid", "high"]
DEFAULT_MODE_ORDER: list[str] = ["auto", "cool", "dry", "fan", "heat"]

# In diesen Modi ist die Zieltemperatur einstellbar (sonst wird Lüfter gescrollt).
DEFAULT_TEMP_MODES: list[str] = ["cool", "heat", "auto"]
DEFAULT_TEMP_MIN: int = 16
DEFAULT_TEMP_MAX: int = 30

# Nerd-Font-Icons (JetBrainsMono/Symbols Nerd Font) — frei anpassbar.
DEFAULT_ICONS: dict[str, str] = {
    "power": "󰐥",          # Power (für Ein-/Ausschalten im Menü)
    "off": "󰜗",           # Schneeflocke (gedimmt via CSS)
    "cool": "󰜗",          # Schneeflocke
    "heat": "󰈸",          # Flamme
    "dry": "󰖎",           # Wasser-Prozent
    "fan": "󰈐",           # Ventilator
    "auto": "󰔏",          # Thermometer
    "disconnected": "󰤭",  # offline
}


def config_home() -> Path:
    """Verzeichnis für devices.json / .env.

    Reihenfolge: $AC_HOME > ~/.config/ac. Bewusst unabhängig vom cwd,
    damit der Aufruf aus Waybar (beliebiges Arbeitsverzeichnis) immer dieselben
    Gerätedaten findet.
    """
    env = os.environ.get("AC_HOME")
    if env:
        return Path(env).expanduser()
    return Path.home() / ".config" / "ac"


def _parse_env_file(path: Path) -> dict[str, str]:
    out: dict[str, str] = {}
    if not path.exists():
        return out
    for raw in path.read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, val = line.partition("=")
        out[key.strip()] = val.strip().strip('"').strip("'")
    return out


def load_env() -> None:
    """Lädt .env (cwd + Config-Home) nach os.environ, ohne Bestehendes zu überschreiben."""
    for path in (Path.cwd() / ".env", config_home() / ".env"):
        for k, v in _parse_env_file(path).items():
            os.environ.setdefault(k, v)


def credentials() -> dict[str, str]:
    load_env()
    return {
        "region": os.environ.get("TUYA_API_REGION", "eu"),
        "key": os.environ.get("TUYA_API_KEY", ""),
        "secret": os.environ.get("TUYA_API_SECRET", ""),
    }


def devices_path() -> Path:
    return config_home() / "devices.json"


def load_store() -> dict[str, Any]:
    path = devices_path()
    if not path.exists():
        return {"selected": None, "devices": {}}
    return json.loads(path.read_text())


def save_store(store: dict[str, Any]) -> None:
    home = config_home()
    home.mkdir(parents=True, exist_ok=True)
    path = devices_path()
    path.write_text(json.dumps(store, indent=2, ensure_ascii=False))
    # devices.json enthält den Local Key -> nur für den Besitzer lesbar.
    try:
        path.chmod(0o600)
    except OSError:
        pass


def selected_device(store: dict[str, Any] | None = None) -> dict[str, Any] | None:
    store = store or load_store()
    sel = store.get("selected")
    if not sel:
        return None
    return store.get("devices", {}).get(sel)


def ensure_device_defaults(dev: dict[str, Any]) -> dict[str, Any]:
    dev.setdefault("dps", dict(DEFAULT_DPS))
    dev.setdefault("mode_values", dict(DEFAULT_MODE_VALUES))
    dev.setdefault("fan_values", dict(DEFAULT_FAN_VALUES))
    dev.setdefault("fan_order", list(DEFAULT_FAN_ORDER))
    dev.setdefault("mode_order", list(DEFAULT_MODE_ORDER))
    dev.setdefault("temp_modes", list(DEFAULT_TEMP_MODES))
    dev.setdefault("temp_min", DEFAULT_TEMP_MIN)
    dev.setdefault("temp_max", DEFAULT_TEMP_MAX)
    dev.setdefault("icons", dict(DEFAULT_ICONS))
    return dev
