#!/bin/bash

# Launcher, ported from omarchy-launch-walker. Two differences: no uwsm-app
# wrapper (this session does not run under uwsm) and the service is started
# here rather than by a ~/.config/autostart entry.
#
# GSK_RENDERER=cairo is omarchy's setting — gtk4's default ngl renderer draws
# the layer-shell surface wrong on some drivers.

if ! pgrep -x elephant >/dev/null; then
  setsid elephant >/dev/null 2>&1 &
fi

if ! pgrep -f "walker --gapplication-service" >/dev/null; then
  setsid env GSK_RENDERER=cairo walker --gapplication-service >/dev/null 2>&1 &
  # The service needs a moment before the first client connects.
  sleep 0.3
fi

exec walker --width 644 --maxheight 300 --minheight 300 "$@"
