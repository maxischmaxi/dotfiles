#!/usr/bin/env bash
set -x
echo "WAYLAND_DISPLAY=$WAYLAND_DISPLAY" >> ~/gamescope-debug.log
echo "XDG_SESSION_TYPE=$XDG_SESSION_TYPE" >> ~/gamescope-debug.log
env >> ~/gamescope-debug.log
gamescope --verbose --backend wayland -w 1920 -h 1080 -W 2560 -H 1440 \
-F nis -r 120 --adaptive-sync -- "$@" >> ~/gamescope-debug.log 2>&1
