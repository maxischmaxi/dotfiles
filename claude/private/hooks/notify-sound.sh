#!/usr/bin/env bash
# Plays the chime when the main session stops or waits for the user.
# Silent for subagents and headless (sdk) sessions.

SOUND="$HOME/claude/sounds/claude-done.mp3"
STAMP="${XDG_RUNTIME_DIR:-/tmp}/claude-notify-sound.stamp"

input=$(cat)

# subagents and teammates carry an agent_id
if [ -n "$(jq -r '.agent_id // empty' <<<"$input" 2>/dev/null)" ]; then
    exit 0
fi

case "${CLAUDE_CODE_ENTRYPOINT-}" in
sdk*) exit 0 ;;
esac

# debounce: several events can fire for the same prompt
now=$(date +%s)
last=$(cat "$STAMP" 2>/dev/null || echo 0)
if [ $((now - last)) -lt 3 ]; then
    exit 0
fi
echo "$now" >"$STAMP"

# native pipewire client; the timeout guards against a hung audio server
timeout 5 pw-play "$SOUND" >/dev/null 2>&1 || true
