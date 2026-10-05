#!/usr/bin/env bash
# Setzt den RandR-Primary-Output in Xwayland auf den Samsung Odyssey
# (Hyprland: DP-2 @ 0x0, der linke Arbeits-Monitor).
#
# Hintergrund: raylib/GLFW-Spiele (z.B. ~/stuff/programming/minecraft)
# zentrieren ihr Fenster beim InitWindow auf dem Monitor, den GLFW als
# "primary" meldet. Ohne expliziten Primary ist das der Output mit der
# niedrigsten X-Position — der ASUS (DP-1, rechts) — und das Fenster
# "verschwindet" vom Monitor, an dem man arbeitet.
#
# Xwayland startet asynchron zum Hyprland-Autostart, daher Retry-Loop.
for _ in $(seq 1 20); do
	if DISPLAY=:0 xrandr --output DP-2 --primary 2>/dev/null; then
		exit 0
	fi
	sleep 0.5
done
exit 1