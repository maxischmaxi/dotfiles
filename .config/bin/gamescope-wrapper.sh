#!/usr/bin/env bash
env XDG_SESSION_TYPE=wayland WLR_NO_HARDWARE_CURSORS=1 \
__GLX_VENDOR_LIBRARY_NAME=nvidia GBM_BACKEND=nvidia-drm \
gamescope --backend wayland -w 1920 -h 1080 -W 2560 -H 1440 -F nis -r 120 --adaptive-sync -- "$@"
