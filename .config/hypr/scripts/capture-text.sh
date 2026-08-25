#!/bin/bash

# Extract text from a screen region with OCR. Ported from omarchy-capture-text.
# Set OCR_LANGS to add languages, e.g. "eng+deu" (needs tesseract-data-deu).

# Keep hyprpicker alive until after grim captures so the screenshot sees the
# frozen overlay rather than live content shifting during teardown.
cleanup_freeze() {
  [[ -n $PID ]] && kill $PID 2>/dev/null
}
trap cleanup_freeze EXIT

hyprpicker -r -z >/dev/null 2>&1 &
PID=$!
sleep .1
SELECTION=$(slurp 2>/dev/null)

[[ -z $SELECTION ]] && exit 0

TEXT=$(grim -g "$SELECTION" - | tesseract stdin stdout --oem 1 --psm 6 -l "${OCR_LANGS:-eng}" --dpi 300 -c preserve_interword_spaces=1 2>/dev/null) || exit 1

[[ -z $TEXT ]] && exit 1

printf "%s" "$TEXT" | wl-copy
notify-send -a screenshot "Copied text from selection to clipboard"
