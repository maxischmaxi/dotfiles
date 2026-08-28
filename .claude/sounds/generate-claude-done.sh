#!/usr/bin/env bash
# Generiert den sanften Zwei-Ton-Chime für den Claude-Code-Stop-Hook.
# Hüllkurve wird sample-genau via aevalsrc berechnet (kein Zipper-Knistern
# wie beim volume-Filter mit eval=frame).
# Zum Anpassen: Frequenzen (E4 329.63 / A4 440 + Oktav-Obertöne), Decay-Raten
# (exp(-N*t)) oder die Gesamtlautstärke (volume=0.35 ≈ -16 dBFS Peak) ändern
# und neu ausführen.
set -euo pipefail

OUT="$HOME/.claude/sounds/claude-done.mp3"

ffmpeg -y -loglevel error \
  -f lavfi -i "aevalsrc=exprs='\
min(1\,t/0.012)*(0.30*exp(-4.5*t)*sin(2*PI*329.63*t)+0.10*exp(-7*t)*sin(2*PI*659.25*t)) \
+ if(lt(t\,0.18)\,0\,min(1\,(t-0.18)/0.012)*(0.30*exp(-4.5*(t-0.18))*sin(2*PI*440*(t-0.18))+0.10*exp(-7*(t-0.18))*sin(2*PI*880*(t-0.18))))\
':s=44100:d=1.5" \
  -af "volume=0.35,afade=t=out:st=1.3:d=0.2" \
  -codec:a libmp3lame -q:a 2 "$OUT"

echo "Generiert: $OUT"
ffmpeg -i "$OUT" -af volumedetect -f null - 2>&1 | grep -E 'max_volume|mean_volume'
