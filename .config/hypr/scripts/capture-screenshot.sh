#!/bin/bash

# Take a screenshot. Ported from omarchy-capture-screenshot; the notification
# goes through notify-send instead of omarchy's own D-Bus helper.
#
# Usage: capture-screenshot.sh [smart|region|windows|fullscreen] [slurp|copy|save]

[[ -f ~/.config/user-dirs.dirs ]] && source ~/.config/user-dirs.dirs
OUTPUT_DIR="${SCREENSHOT_DIR:-${XDG_PICTURES_DIR:-$HOME/Pictures}}"
mkdir -p "$OUTPUT_DIR"

# Pressing the key again while a selection is up cancels instead of stacking
# a second picker.
pkill slurp && exit 0

SCREENSHOT_EDITOR="${SCREENSHOT_EDITOR_CMD:-tensaku-edit}"

MODE="${1:-smart}"
PROCESSING="${2:-slurp}"

# The picker leaves the screen freeze running (PID on its first output line)
# so grim captures the frozen overlay rather than live content shifting
# during teardown.
#
# Software-composited cursors (Hyprland's fallback on GPUs without working
# hardware cursors) are baked into the frames grim captures, so force
# hardware cursors until after grim runs and restore the setting on exit.
NO_HW_CURSORS=$(hyprctl getoption cursor:no_hardware_cursors -j | jq '.int')

set_no_hw_cursors() {
  hyprctl eval "hl.config({ cursor = { no_hardware_cursors = $1 } })" &>/dev/null ||
    hyprctl keyword cursor:no_hardware_cursors "$1" &>/dev/null
}

cleanup() {
  [[ -n $FREEZE_PID ]] && kill $FREEZE_PID 2>/dev/null
  set_no_hw_cursors "$NO_HW_CURSORS"
}
trap cleanup EXIT

set_no_hw_cursors 0
{ read -r FREEZE_PID; read -r SELECTION; } < <(~/.config/hypr/scripts/capture-region.sh "$MODE" --keep-freeze)

[[ -z $SELECTION ]] && exit 0

FILENAME="screenshot-$(date +'%Y-%m-%d_%H-%M-%S').png"
FILEPATH="$OUTPUT_DIR/$FILENAME"

case "$PROCESSING" in
  slurp)
    grim -g "$SELECTION" "$FILEPATH" || exit 1
    echo "$FILEPATH"
    wl-copy --type image/png <"$FILEPATH"

    # Two actions on purpose: "default" is what a click on the notification
    # body invokes, "edit" renders as a button. Without the default one,
    # clicking the body does nothing at all.
    #
    # -A blocks until the notification is clicked or expires, so the whole
    # thing is detached — the screenshot is already saved either way.
    setsid bash -c '
      action=$(notify-send -a screenshot -i "$2" \
        "Screenshot saved to clipboard and file" "Click to edit" \
        -A "default=Edit" -A "edit=Edit" 2>/dev/null)
      [[ $action == default || $action == edit ]] || exit 0
      if ! command -v "${1%% *}" >/dev/null; then
        notify-send -a screenshot -u critical "Screenshot editor not found: ${1%% *}"
        exit 1
      fi
      exec $1 "$2"
    ' _ "$SCREENSHOT_EDITOR" "$FILEPATH" >/dev/null 2>&1 &
    ;;
  copy)
    grim -g "$SELECTION" - | wl-copy --type image/png
    ;;
  save)
    grim -g "$SELECTION" "$FILEPATH" || exit 1
    echo "$FILEPATH"
    ;;
esac
