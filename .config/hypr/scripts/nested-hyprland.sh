#!/usr/bin/env bash
# Starts a nested Hyprland in a window, for plugin development.
#
# Unsetting HYPRLAND_INSTANCE_SIGNATURE matters: without it the child inherits
# the parent's signature and every hyprctl call inside the nested session would
# steer the real compositor instead.
set -euo pipefail

CONFIG="${1:-$HOME/.config/hypr/nested.lua}"

if [ ! -f "$CONFIG" ]; then
	echo "config not found: $CONFIG" >&2
	exit 1
fi

Hyprland --verify-config -c "$CONFIG" >/dev/null || {
	echo "config has errors, not starting" >&2
	exit 1
}

echo "starting nested Hyprland — reach it with: hyprctl -i 1 …"
exec env -u HYPRLAND_INSTANCE_SIGNATURE Hyprland -c "$CONFIG"
