#!/bin/bash
mons=/tmp/hypr-last-workspaces
focused=/tmp/hypr-last-focused-workspace

if [ -f "$mons" ]; then
    while read -r mon ws; do
        [ -n "$mon" ] && [ -n "$ws" ] || continue
        hyprctl dispatch focusmonitor "$mon" >/dev/null
        hyprctl dispatch workspace "$ws" >/dev/null
    done < "$mons"
fi

if [ -f "$focused" ]; then
    ws=$(cat "$focused")
    [ -n "$ws" ] && hyprctl dispatch workspace "$ws" >/dev/null
fi
