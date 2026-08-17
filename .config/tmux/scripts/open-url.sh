#!/usr/bin/env bash
# Reads a line from stdin, extracts first URL, opens it via xdg-open.
url=$(grep -oE 'https?://[^[:space:]"<>`'"'"')]+' | head -n1 | sed 's/[.,;:!?)]*$//')
if [ -n "$url" ]; then
    xdg-open "$url" >/dev/null 2>&1 &
    tmux display-message "opening: ${url}"
else
    tmux display-message "no URL found on line"
fi
