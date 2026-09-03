# ══════════════════════════════════════════════════════════════════════
# 30-tools.zsh — git-Aliase (global) + Vault (Secret-Manager).
# VOR den Shell-Aliasen (40) laden: so werden Definitionen aus dem Vault
# (Funktionen/Aliase) von unseren eigenen Aliasen in 40 überschrieben —
# wie bisher in der monolithischen .zshrc auch.
# ══════════════════════════════════════════════════════════════════════

# git aliases (yolo, conflicts) and rerere live in the global git config and
# are set once per machine by ~/dotfiles/setup-git.sh, not on every shell start.

# Vault — encrypted secret manager (replaces plaintext .tokens)
# Direkt aus dem vault-Repo gesourced, kein Symlink: folgt so automatisch
# $PROJECTS_DIR. Fehlt das Repo (frische Maschine), passiert einfach nichts.
[ -f "$PROJECTS_DIR/vault/zsh/vault.zsh" ] && source "$PROJECTS_DIR/vault/zsh/vault.zsh"
