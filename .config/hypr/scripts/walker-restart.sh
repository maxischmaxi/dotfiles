#!/bin/bash

# Restart walker and its data provider — needed after a config or theme edit,
# and what walker's own "Restart Walker" emergency entry calls.

pkill -x walker
pkill -x elephant
sleep 0.2
setsid elephant >/dev/null 2>&1 &
setsid env GSK_RENDERER=cairo walker --gapplication-service >/dev/null 2>&1 &
