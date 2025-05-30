#! /usr/bin/env bash

echo "Switching focus to ${1} pane or window" >> ~/.config/debug.log

YABAI_DIRECTION=$1
case $1 in
    "west")
        PANE_DIRECTION="left"
        DIRECTION_FLAG="-L"
        ;;
    "south")
        PANE_DIRECTION="bottom"
        DIRECTION_FLAG="-D"
        ;;
    "north")
        PANE_DIRECTION="top"
        DIRECTION_FLAG="-U"
        ;;
    "east")
        PANE_DIRECTION="right"
        DIRECTION_FLAG="-R"
        ;;
esac

if [[ $(tmux display-message -p "#{pane_at_${PANE_DIRECTION}}") == "0" ]]; then
    tmux select-pane ${DIRECTION_FLAG} &>/dev/null
else
    yabai -m window --focus ${YABAI_DIRECTION} >/dev/null 2>&1 || true
fi
