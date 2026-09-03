#! /usr/bin/env bash
# Called by nvim (config.tmux_navigator) when the cursor is already at the
# edge of nvim: move to the neighbouring tmux pane in that direction.
# tmux itself no longer needs this script, its root bindings do the same
# with a format check (see tmux.conf).

DIRECTION=$1
KEY=$2 # optional key (e.g. C-h), handed back to emacs at the edge

case $DIRECTION in
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
    *)
        exit 0
        ;;
esac

if [[ $(tmux display-message -p "#{pane_at_${PANE_DIRECTION}}") == "0" ]]; then
    tmux select-pane "$DIRECTION_FLAG" &>/dev/null || true
    exit 0
fi

# At the edge. Emacs gets the key back so C-h keeps working as its prefix.
if [[ -n "$KEY" ]]; then
    PANE_CMD=$(tmux display-message -p "#{pane_current_command}")
    if [[ "$PANE_CMD" == "emacs" || "$PANE_CMD" == "emacsclient" ]]; then
        tmux send-keys "$KEY"
        exit 0
    fi
fi

# macOS: hand the focus change to yabai. Linux: stop here on purpose, moving
# out of tmux into another Hyprland window but not back in is confusing.
if [[ "$OSTYPE" == darwin* ]]; then
    yabai -m window --focus "$DIRECTION" >/dev/null 2>&1 || true
fi
