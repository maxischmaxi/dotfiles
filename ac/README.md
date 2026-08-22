# ac

CLI + Waybar-Modul zum Steuern einer Tuya/SmartLife-Klimaanlage (Marke
„Hantech") über das lokale Netz — auf Basis von
[tinytuya](https://github.com/jasonacox/tinytuya).

Liegt unter `~/.config/ac` und wird als Binary nach `~/.local/bin/ac`
installiert (von Waybar von überall aufrufbar).

## Installation / Update

```sh
uv tool install --editable ~/.config/ac   # einmalig; --editable = Code-Edits wirken sofort
```

Gerätedaten und Credentials liegen immer in `~/.config/ac/` (per `AC_HOME`
überschreibbar) — unabhängig vom Arbeitsverzeichnis, damit der Aufruf aus Waybar
funktioniert.

## Ersteinrichtung

1. **Credentials** — `.env` aus `.env.example` anlegen, Client ID / Secret /
   Region (für DE meist `eu`) aus dem Tuya-Cloud-Projekt eintragen.
2. **Local Key holen:** `ac sync`
3. **Lokale IP finden** (gleiches WLAN): `ac scan` (ggf. `--force`)
4. **DP-Mapping verifizieren** (DP-Nummern variieren je Modell):
   `ac dps` → Schalter in der App umlegen → erneut `ac dps` → Änderung
   zuordnen mit `ac map set <feld> <dp>` bzw. `ac map mode/fan <name> <wert>`.

> ⚠️ Tuya erlaubt nur **eine** lokale Verbindung gleichzeitig. Für lokale
> Befehle die SmartLife-App schließen. ac serialisiert eigene Zugriffe per
> File-Lock (`~/.config/ac/.device.lock`).

## Befehle

```sh
ac status            # Zustand (Tabelle)
ac state             # Zustand als JSON (für Skripte)
ac waybar            # Waybar-JSON ({text,tooltip,class})

ac toggle            # an/aus umschalten
ac on | off
ac temp 22           # Zieltemperatur absolut
ac temp up|down      # relativ (--step N)
ac mode cool         # cool/heat/auto/dry/fan
ac mode next         # Modus durchschalten
ac fan high          # low/mid/high/auto
ac fan up|down|cycle # Lüfter durchschalten
ac scroll up|down    # mode-abhängig: Temp (cool/heat/auto) sonst Lüfter
ac set 1 true        # beliebigen DP roh setzen

ac menu              # interaktives rofi/wofi/fuzzel-Menü (mode-abhängig)
ac devices | use <x> # Geräteliste / aktives Gerät wählen
ac map show|set|mode|fan   # DP-Mapping pflegen
```

## Waybar-Modul

Modul `custom/ac` (in `~/.config/waybar/config.jsonc`):

| Aktion | Funktion |
|--------|----------|
| Linksklick | an/aus |
| Mittelklick | Lüfter durchschalten |
| Rechtsklick | mode-abhängiges Menü (rofi) |
| Scrollen | cool/heat/auto → Temperatur, sonst Lüfter |

Anzeige/Akzentfarbe richten sich nach dem Modus (CSS-Klassen `cool/heat/dry/
fan/auto/off/disconnected` in `style.css`). Refresh nach Aktionen via
`pkill -RTMIN+10 waybar` (Modul-`signal: 10`).

Übernehmen: `~/.config/waybar/reload.sh`.

Menü-Launcher: automatisch rofi → wofi → fuzzel; per `AC_MENU` überschreibbar.

## Dateien

- `.env` — Cloud-Credentials *(gitignored)*
- `devices.json` — Geräte inkl. **Local Key** + DP-Mapping *(gitignored, `chmod 600`)*

## Architektur

- `config.py` — Persistenz, Defaults (DP-Map, Reihenfolgen, Icons)
- `logic.py` — **pure**, testbare Domänenlogik (Waybar-Format, Menü-Einträge, Stepping)
- `device.py` — Tuya-I/O (Cloud-Sync, LAN-Scan, lokale Steuerung, File-Lock)
- `menu.py` — rofi/wofi/fuzzel-Menü
- `cli.py` — Typer-CLI
