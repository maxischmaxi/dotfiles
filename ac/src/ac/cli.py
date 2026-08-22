"""ac — CLI zum Steuern einer Tuya/SmartLife-Klimaanlage über das lokale Netz."""

from __future__ import annotations

import json
from typing import Any, Optional

import typer
from rich.console import Console
from rich.table import Table

from . import config, device, logic, menu
from .device import ACError

app = typer.Typer(
    no_args_is_help=True,
    add_completion=False,
    help="Steuert eine Tuya/SmartLife-Klimaanlage lokal (LAN).",
)
map_app = typer.Typer(no_args_is_help=True, help="DP-Mapping anzeigen/anpassen.")
app.add_typer(map_app, name="map")

console = Console()
err = Console(stderr=True)


def _die(msg: str) -> None:
    err.print(f"[bold red]Fehler:[/] {msg}")
    raise typer.Exit(code=1)


def _selected() -> dict[str, Any]:
    dev = config.selected_device()
    if not dev:
        _die("Kein Gerät ausgewählt. Erst `ac sync` ausführen.")
    return config.ensure_device_defaults(dev)  # type: ignore[arg-type]


def _reverse(value: Any, mapping: dict[str, str]) -> str:
    for name, raw in mapping.items():
        if str(raw) == str(value):
            return name
    return f"? ({value})"


def _parse_value(raw: str) -> Any:
    low = raw.lower()
    if low in ("true", "on", "an", "1"):
        return True
    if low in ("false", "off", "aus", "0"):
        return False
    try:
        return int(raw)
    except ValueError:
        return raw


# --------------------------------------------------------------------------- #
# Einrichtung
# --------------------------------------------------------------------------- #
@app.command()
def sync() -> None:
    """Geräte inkl. Local Key aus der Tuya-Cloud holen und speichern."""
    try:
        devices = device.cloud_sync()
    except ACError as e:
        _die(str(e))
    console.print(f"[green]✓[/] {len(devices)} Gerät(e) synchronisiert.")
    for d in devices:
        console.print(f"  • {d['name']}  [dim]({d['id']})[/]  key={'✓' if d.get('key') else '✗'}")
    console.print("\nNächster Schritt: [bold]ac scan[/] (im selben WLAN), um die lokale IP zu finden.")


@app.command()
def scan(
    force: bool = typer.Option(False, "--force", help="Aktiv das Subnetz scannen (langsamer)."),
    retry: Optional[int] = typer.Option(None, "--retry", help="Anzahl Scan-Durchläufe."),
) -> None:
    """LAN nach Geräten durchsuchen und lokale IP/Protokollversion speichern."""
    console.print("[dim]Scanne LAN … (kann ~15 s dauern)[/]")
    try:
        matched = device.lan_scan(maxretry=retry, force=force)
    except ACError as e:
        _die(str(e))
    if not matched:
        _die(
            "Kein bekanntes Gerät im LAN gefunden. Im selben WLAN? "
            "Sonst mit `--force` erneut versuchen."
        )
    for dev_id, ip in matched.items():
        console.print(f"[green]✓[/] {dev_id} → {ip}")


@app.command()
def devices() -> None:
    """Konfigurierte Geräte auflisten."""
    store = config.load_store()
    devs = store.get("devices", {})
    if not devs:
        _die("Keine Geräte. Erst `ac sync` ausführen.")
    table = Table(title="Geräte")
    table.add_column("")
    table.add_column("Name")
    table.add_column("ID", style="dim")
    table.add_column("IP")
    table.add_column("Ver")
    table.add_column("Key")
    for dev_id, d in devs.items():
        sel = "→" if dev_id == store.get("selected") else ""
        table.add_row(
            sel, d.get("name", ""), dev_id, d.get("ip", "—"),
            str(d.get("version", "")), "✓" if d.get("key") else "✗",
        )
    console.print(table)


@app.command()
def use(target: str = typer.Argument(..., help="Geräte-ID oder (Teil-)Name.")) -> None:
    """Aktives Gerät wählen."""
    store = config.load_store()
    devs = store.get("devices", {})
    match = None
    if target in devs:
        match = target
    else:
        for dev_id, d in devs.items():
            if target.lower() in d.get("name", "").lower():
                match = dev_id
                break
    if not match:
        _die(f"Kein Gerät passend zu '{target}'.")
    store["selected"] = match
    config.save_store(store)
    console.print(f"[green]✓[/] Aktiv: {devs[match].get('name')} ({match})")


# --------------------------------------------------------------------------- #
# Status / Diagnose
# --------------------------------------------------------------------------- #
@app.command()
def status() -> None:
    """Aktuellen Zustand anzeigen (interpretiert)."""
    dev = _selected()
    try:
        st = device.read_state()
    except ACError as e:
        _die(str(e))
    if not st.get("online"):
        _die(f"Gerät nicht erreichbar: {st.get('error')}")

    table = Table(title=f"{dev.get('name')} ({dev.get('ip')})")
    table.add_column("Feld")
    table.add_column("Wert")
    table.add_row("Power", "an" if st["power"] else "aus")
    table.add_row("Ist-Temp", f"{st['temp_current']}°")
    table.add_row("Ziel-Temp", f"{st['temp_set']}°")
    table.add_row("Modus", st["mode"] or f"? ({st['mode_raw']})")
    table.add_row("Lüfter", st["fan"] or f"? ({st['fan_raw']})")
    console.print(table)


@app.command()
def state() -> None:
    """Zustand als JSON ausgeben (maschinenlesbar)."""
    _selected()
    try:
        st = device.read_state(fast=True)
    except ACError as e:
        print(json.dumps({"online": False, "error": str(e)}))
        raise typer.Exit(code=1)
    st.pop("device", None)  # enthält Local Key — nicht ausgeben
    print(json.dumps(st, ensure_ascii=False))


@app.command()
def waybar() -> None:
    """Waybar-JSON ausgeben ({text, tooltip, class}). Für den Modul-`exec`."""
    try:
        dev = _selected()
        st = device.read_state(fast=True)
    except ACError as e:
        print(json.dumps({"text": "󰜗", "tooltip": f"AC: {e}", "class": "disconnected"}))
        return
    print(json.dumps(logic.format_waybar(st, dev), ensure_ascii=False))


@app.command()
def dps() -> None:
    """Rohe DP-Werte ausgeben (zum Verifizieren/Mappen des Geräts)."""
    dev = _selected()
    try:
        data = device.status(dev)
    except ACError as e:
        _die(str(e))
    table = Table(title=f"Rohe DPS — {dev.get('name')}")
    table.add_column("DP", justify="right")
    table.add_column("Wert")
    table.add_column("Typ", style="dim")
    for k, v in sorted(data.get("dps", {}).items(), key=lambda kv: int(kv[0]) if kv[0].isdigit() else 0):
        table.add_row(str(k), repr(v), type(v).__name__)
    console.print(table)
    console.print(
        "\n[dim]Tipp: Schalter in der SmartLife-App umlegen, erneut `ac dps` — "
        "der DP, der sich ändert, gehört dazu. Zuordnen mit `ac map set <feld> <dp>`.[/]"
    )


# --------------------------------------------------------------------------- #
# Steuerung
# --------------------------------------------------------------------------- #
def _set_field(field: str, value: Any) -> None:
    dev = _selected()
    dp = dev["dps"].get(field)
    if dp is None:
        _die(f"Kein DP für '{field}' gemappt. Siehe `ac map`.")
    try:
        device.set_dp(int(dp), value, dev)
    except ACError as e:
        _die(str(e))
    console.print(f"[green]✓[/] {field} → {value}")


@app.command()
def on() -> None:
    """Klimaanlage einschalten."""
    _set_field("power", True)


@app.command()
def off() -> None:
    """Klimaanlage ausschalten."""
    _set_field("power", False)


@app.command()
def toggle() -> None:
    """An/aus umschalten (für Waybar-Linksklick)."""
    try:
        on = device.toggle()
    except ACError as e:
        _die(str(e))
    console.print(f"[green]✓[/] {'an' if on else 'aus'}")


@app.command()
def temp(
    value: str = typer.Argument(..., help="Grad-Zahl, oder 'up'/'down' (relativ)."),
    step: int = typer.Option(1, "--step", help="Schrittweite für up/down."),
) -> None:
    """Zieltemperatur setzen (absolut) oder ändern (up/down)."""
    try:
        if value in ("up", "down"):
            new = device.step_temp(step if value == "up" else -step)
        else:
            new = device.set_temp(int(value))
    except ValueError:
        _die(f"Ungültige Temperatur '{value}'. Zahl oder up/down.")
    except ACError as e:
        _die(str(e))
    console.print(f"[green]✓[/] Ziel-Temp → {new}°")


@app.command()
def mode(
    name: str = typer.Argument(..., help="cool/heat/auto/dry/fan oder 'next'."),
    raw: bool = typer.Option(False, "--raw", help="Wert roh senden (ohne Mapping)."),
) -> None:
    """Betriebsmodus setzen oder durchschalten (next)."""
    try:
        new = device.next_mode() if name == "next" else device.set_mode(name, raw=raw)
    except ACError as e:
        _die(str(e))
    console.print(f"[green]✓[/] Modus → {new}")


@app.command()
def fan(
    name: str = typer.Argument(..., help="low/mid/high/auto, oder up/down/cycle."),
    raw: bool = typer.Option(False, "--raw", help="Wert roh senden (ohne Mapping)."),
) -> None:
    """Lüfterstufe setzen oder durchschalten (up/down/cycle)."""
    try:
        if name in ("up", "down"):
            new = device.step_fan(1 if name == "up" else -1)
        elif name == "cycle":
            new = device.step_fan(1, wrap=True)
        else:
            new = device.set_fan(name, raw=raw)
    except ACError as e:
        _die(str(e))
    console.print(f"[green]✓[/] Lüfter → {new}")


@app.command()
def scroll(direction: str = typer.Argument(..., help="up oder down.")) -> None:
    """Mode-abhängig scrollen: Temperatur (cool/heat/auto), sonst Lüfter."""
    if direction not in ("up", "down"):
        _die("Richtung muss 'up' oder 'down' sein.")
    try:
        kind, val = device.do_scroll(direction)
    except ACError as e:
        _die(str(e))
    label = "Ziel-Temp" if kind == "temp" else "Lüfter"
    console.print(f"[green]✓[/] {label} → {val}")


@app.command(name="menu")
def menu_cmd() -> None:
    """Interaktives Menü (mode-abhängig) via rofi/wofi/fuzzel öffnen."""
    try:
        menu.run_menu()
    except ACError as e:
        _die(str(e))


@app.command(name="set")
def set_dp(
    dp: int = typer.Argument(..., help="DP-Nummer."),
    value: str = typer.Argument(..., help="Wert (true/false/Zahl/Text)."),
) -> None:
    """Beliebigen DP roh setzen (zum Experimentieren/Mappen)."""
    dev = _selected()
    parsed = _parse_value(value)
    try:
        device.set_dp(dp, parsed, dev)
    except ACError as e:
        _die(str(e))
    console.print(f"[green]✓[/] DP {dp} → {parsed!r}")


# --------------------------------------------------------------------------- #
# Mapping
# --------------------------------------------------------------------------- #
@map_app.command("show")
def map_show() -> None:
    """Aktuelles DP-Mapping des Geräts anzeigen."""
    dev = _selected()
    table = Table(title=f"DP-Mapping — {dev.get('name')}")
    table.add_column("Feld")
    table.add_column("DP", justify="right")
    for field, dp in dev["dps"].items():
        table.add_row(field, str(dp))
    console.print(table)
    console.print(f"[dim]Modus-Werte:[/] {dev['mode_values']}")
    console.print(f"[dim]Lüfter-Werte:[/] {dev['fan_values']}")


@map_app.command("set")
def map_set(
    field: str = typer.Argument(..., help="power/temp_set/temp_current/mode/fan."),
    dp: int = typer.Argument(..., help="DP-Nummer am Gerät."),
) -> None:
    """Ein Feld einer DP-Nummer zuordnen."""
    store = config.load_store()
    dev = config.selected_device(store)
    if not dev:
        _die("Kein Gerät ausgewählt.")
    config.ensure_device_defaults(dev)
    dev["dps"][field] = dp  # type: ignore[index]
    config.save_store(store)
    console.print(f"[green]✓[/] {field} → DP {dp}")


def _set_enum(table_key: str, name: str, raw: str) -> None:
    store = config.load_store()
    dev = config.selected_device(store)
    if not dev:
        _die("Kein Gerät ausgewählt.")
    config.ensure_device_defaults(dev)
    parsed = _parse_value(raw)
    dev[table_key][name] = parsed  # type: ignore[index]
    config.save_store(store)
    console.print(f"[green]✓[/] {table_key}: {name} → {parsed!r}")


@map_app.command("mode")
def map_mode(
    name: str = typer.Argument(..., help="Freundlicher Name, z. B. cool."),
    raw: str = typer.Argument(..., help="Roher Geräte-Wert, z. B. cold."),
) -> None:
    """Modus-Namen einem rohen Enum-Wert zuordnen."""
    _set_enum("mode_values", name, raw)


@map_app.command("fan")
def map_fan(
    name: str = typer.Argument(..., help="Freundlicher Name, z. B. mid."),
    raw: str = typer.Argument(..., help="Roher Geräte-Wert, z. B. med."),
) -> None:
    """Lüfterstufen-Namen einem rohen Enum-Wert zuordnen."""
    _set_enum("fan_values", name, raw)


def main() -> None:
    app()
