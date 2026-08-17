#!/bin/bash

# Source Tokyo Night theme for consistent colors
THEME_DIR="$HOME/.config/tmux/plugins/tokyo-night-tmux/src"
source "$THEME_DIR/themes.sh"

RESET="#[fg=${THEME[foreground]},bg=${THEME[background]},nobold,noitalics,nounderscore,nodim]"

# Slack D-Bus SNI status
slack_dot=""
if items=$(busctl --user get-property org.kde.StatusNotifierWatcher \
    /StatusNotifierWatcher org.kde.StatusNotifierWatcher RegisteredStatusNotifierItems 2>/dev/null); then
    slack_dest=$(echo "$items" | grep -oP ':\d+\.\d+(?=/StatusNotifierItem)' | while read -r dest; do
        id=$(busctl --user get-property "$dest" /StatusNotifierItem org.kde.StatusNotifierItem Id 2>/dev/null)
        if [[ "$id" == *"chrome_status_icon"* ]]; then
            echo "$dest"
            break
        fi
    done)
    if [[ -n "$slack_dest" ]]; then
        status=$(busctl --user get-property "$slack_dest" /StatusNotifierItem \
            org.kde.StatusNotifierItem Status 2>/dev/null)
        if [[ "$status" == *"NeedsAttention"* ]]; then
            slack_dot=" #[fg=#f7768e,bg=${THEME[bblack]}]●#[fg=${THEME[cyan]},bg=${THEME[bblack]}]"
        fi
    fi
fi

echo "${RESET}#[fg=${THEME[cyan]},bg=${THEME[bblack]}]${slack_dot}"
