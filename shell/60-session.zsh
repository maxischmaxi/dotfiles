# ══════════════════════════════════════════════════════════════════════
# 60-session.zsh — tmux-Autostart.
# WICHTIG: Dieser `exec tmux` ersetzt den Shell-Prozess. Alles in 70-plugins
# läuft daher NUR in der finalen (tmux-)Shell — fzf/Plugins landen bewusst
# erst dort, damit fzf Tab nicht durch den Exec-Neustart überschrieben wird.
# Kein tmux-Autostart auf der Linux-Konsole (TERM=linux): Compositors wie
# rift brauchen das VT als Controlling-TTY — unter tmux sind VT-ioctls
# (Keyboard-Mute, VT-Switch) mit EPERM gesperrt und Input leakt ins TTY.
# ══════════════════════════════════════════════════════════════════════
if [ -z "$TMUX" ] && [ -z "$INSIDE_EMACS" ] && [ -z "$VSCODE_INJECTION" ] && [ "$TERM" != "linux" ]; then
  exec tmux new-session -A -s main
fi
