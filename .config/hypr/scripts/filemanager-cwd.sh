#!/bin/bash

# Open the file manager in the working directory of the focused terminal.
# Ported from omarchy-cmd-terminal-cwd + omarchy-launch-nautilus-cwd, minus the
# kitty remote-control branch: ghostty has no equivalent socket, so the /proc
# route is the only one that applies here.

terminal_pid=$(hyprctl activewindow -j | jq -r '.pid // empty')
cwd=""

if [[ -n $terminal_pid ]]; then
  # Youngest child of the terminal: with split panes or nested shells that is
  # the one the user is actually typing in.
  shell_pid=$(pgrep -P "$terminal_pid" | tail -n1)

  if [[ -n $shell_pid ]]; then
    cwd=$(readlink -f "/proc/$shell_pid/cwd" 2>/dev/null)
    shell=$(readlink -f "/proc/$shell_pid/exe" 2>/dev/null)
    # Only trust the cwd if the child really is a login shell — otherwise the
    # focused window is some GUI app and its cwd is meaningless.
    grep -Fqsx "$shell" /etc/shells || cwd=""
  fi
fi

[[ -d $cwd ]] || cwd="$HOME"

exec nautilus --new-window "$cwd"
