#! /usr/bin/env bash

DIRECTION=$1
KEY=$2 # optionale Taste (z.B. C-h); wird am Rand an Emacs durchgereicht
HYPR_DIRECTION=l

case $1 in
    "west")
        PANE_DIRECTION="left"
        DIRECTION_FLAG="-L"
        HYPR_DIRECTION="l"
        ;;
    "south")
        PANE_DIRECTION="bottom"
        DIRECTION_FLAG="-D"
        HYPR_DIRECTION="d"
        ;;
    "north")
        PANE_DIRECTION="top"
        DIRECTION_FLAG="-U"
        HYPR_DIRECTION="u"
        ;;
    "east")
        PANE_DIRECTION="right"
        DIRECTION_FLAG="-R"
        HYPR_DIRECTION="r"
        ;;
esac

if [[ $(tmux display-message -p "#{pane_at_${PANE_DIRECTION}}") == "0" ]]; then
    tmux select-pane ${DIRECTION_FLAG} &>/dev/null || true
else
    # Am Rand: keine Navigation in diese Richtung moeglich.
    # Wenn eine Taste uebergeben wurde und im Pane Emacs laeuft, die Taste
    # durchreichen, damit z.B. C-h als Emacs-Prefix funktioniert.
    if [[ -n "$KEY" ]]; then
        PANE_CMD=$(tmux display-message -p "#{pane_current_command}")
        if [[ "$PANE_CMD" == "emacs" || "$PANE_CMD" == "emacsclient" ]]; then
            tmux send-keys "$KEY"
            exit 0
        fi
    fi

    OS=$(uname)
    if [[ "$OS" == "Linux" ]]; then
        if command -v hyprctl &>/dev/null; then
            # it is confusing to be able to move out of tmux but not back in
            # hyprctl dispatch movefocus ${HYPR_DIRECTION} >/dev/null 2>&1 || true
            exit 0
        else
            exit 0
        fi
    elif [[ "$OS" == "Darwin" ]]; then
        yabai -m window --focus ${DIRECTION} >/dev/null 2>&1 || true
    else
        exit 0
    fi
fi
