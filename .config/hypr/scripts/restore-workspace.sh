#!/bin/bash

# Stellt die Workspace-Zuordnung wieder her, die save-workspace.sh vor dem
# Suspend/Lock wegsichert. Läuft aus hypridle (after_sleep_cmd) und teilt
# mit allen anderen Skripten dasselbe Problem: seit Hyprland 0.56 ist
# `hyprctl dispatch <name> <arg>` kaputt — hyprctl übersetzt den Aufruf in
# Lua (`return hl.dispatch(focusmonitor DP-1)`), das kein gültiger Ausdruck
# ist. Erwartet wird die Dispatcher-Form: hl.dsp.<name>({...}).
# `hyprctl dispatch '...'` wertet exakt diesen Ausdruck aus.
# focusmonitor -> hl.dsp.focus({monitor=...}), workspace n -> hl.dsp.focus({workspace=n}).

mons=/tmp/hypr-last-workspaces
focused=/tmp/hypr-last-focused-workspace

if [ -f "$mons" ]; then
    while read -r mon ws; do
        [ -n "$mon" ] && [ -n "$ws" ] || continue
        hyprctl dispatch "hl.dsp.focus({monitor=\"$mon\"})" >/dev/null
        hyprctl dispatch "hl.dsp.focus({workspace=$ws})" >/dev/null
    done < "$mons"
fi

if [ -f "$focused" ]; then
    ws=$(cat "$focused")
    [ -n "$ws" ] && hyprctl dispatch "hl.dsp.focus({workspace=$ws})" >/dev/null
fi
