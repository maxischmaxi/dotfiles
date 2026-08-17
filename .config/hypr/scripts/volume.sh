#!/bin/bash
# Volume-Steuerung für Razer BlackShark V2 Pro
# Steuert den ALSA-Mixer direkt (umgeht PipeWires kubische Kurve).
# PipeWire erkennt ALSA-Änderungen automatisch → Waybar bleibt synchron.
#
# Nutzbereich des Headsets: ALSA 0-20 (~5.6dB).
# Darüber hinaus ändert sich die wahrgenommene Lautstärke kaum.
# MAX anpassen falls nötig.

CARD="R24"
STEP=2
MAX=20

current=$(amixer -D hw:$CARD sget PCM 2>/dev/null | grep 'Mono:' | grep -oP 'Playback \K\d+')
[ -z "$current" ] && exit 1

case "$1" in
    up)
        new=$((current + STEP))
        [ $new -gt $MAX ] && new=$MAX
        amixer -D hw:$CARD sset PCM $new -q
        ;;
    down)
        new=$((current - STEP))
        [ $new -lt 0 ] && new=0
        amixer -D hw:$CARD sset PCM $new -q
        ;;
esac
