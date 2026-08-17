#!/bin/bash
#
# Region aufnehmen — Toggle. Gebunden an CTRL+ALT+5 (hypr/hyprland.lua).
# Bedienung unverändert: einmal drücken wählt per slurp die Region und startet,
# nochmal drücken beendet. Ergebnis liegt weiterhin als .mp4 in ~/Videos.
#
# Encoder ist wl-screenrec statt wf-recorder: das encodet auf der GPU (VAAPI)
# statt mit x264 auf der CPU — bei 3840x2160 der ganze Unterschied zwischen
# "Lüfter dreht auf" und "merkt man nicht".
#
# Fallstrick auf dieser Maschine: die RTX 5070 kann KEIN VAAPI-Encode, der
# nvidia-vaapi-driver beherrscht nur Decode. Encodet wird deshalb auf der
# AMD-iGPU des Ryzen. Deren Render-Node wird unten gesucht statt hart
# verdrahtet, weil die Nummerierung von /dev/dri/renderD* je nach
# Probe-Reihenfolge wechseln kann.

PIDFILE="/tmp/wl-screenrec.pid"
OUTDIR="$HOME/Videos"

if [ -f "$PIDFILE" ] && kill -0 "$(cat $PIDFILE)" 2>/dev/null; then
    # Aufnahme läuft → stoppen. SIGINT lässt wl-screenrec den Container sauber
    # finalisieren; SIGKILL würde eine unbrauchbare Datei hinterlassen.
    kill -SIGINT "$(cat $PIDFILE)"
    rm -f "$PIDFILE"
    notify-send "Aufnahme beendet" "Video gespeichert in $OUTDIR"
else
    # Neue Aufnahme starten
    mkdir -p "$OUTDIR"
    GEOMETRY=$(slurp)
    if [ -n "$GEOMETRY" ]; then
        FILENAME="$OUTDIR/recording-$(date +%Y-%m-%d_%H-%M-%S).mp4"

        # Render-Node der AMD-iGPU suchen (siehe Kommentar oben).
        DRI=""
        for node in /dev/dri/renderD*; do
            drv=$(basename "$(readlink -f "/sys/class/drm/$(basename "$node")/device/driver" 2>/dev/null)" 2>/dev/null)
            if [ "$drv" = "amdgpu" ]; then DRI="$node"; break; fi
        done

        # LIBVA_DRIVER_NAME steht in der zshrc auf "nvidia" und würde den
        # falschen Treiber erzwingen, sobald das Script aus einem Terminal
        # heraus läuft. Hier explizit auf Mesa/AMD setzen.
        if [ -n "$DRI" ]; then
            LIBVA_DRIVER_NAME=radeonsi wl-screenrec -g "$GEOMETRY" -f "$FILENAME" --dri-device "$DRI" &
        else
            wl-screenrec -g "$GEOMETRY" -f "$FILENAME" &
        fi
        PID=$!
        echo $PID > "$PIDFILE"

        # wl-screenrec bricht sofort ab, wenn der Encoder nicht passt. Ohne
        # diese Prüfung fiele das erst auf, wenn das Video später fehlt.
        sleep 0.5
        if kill -0 "$PID" 2>/dev/null; then
            notify-send "Aufnahme gestartet" "Drücke Ctrl+Alt+5 zum Stoppen"
        else
            rm -f "$PIDFILE"
            notify-send -u critical "Aufnahme fehlgeschlagen" \
                "wl-screenrec ist sofort beendet. Zum Debuggen einmal von Hand starten."
        fi
    fi
fi
