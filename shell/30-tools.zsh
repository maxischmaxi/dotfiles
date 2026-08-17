# ══════════════════════════════════════════════════════════════════════
# 30-tools.zsh — git-Aliase (global) + Vault (Secret-Manager).
# VOR den Shell-Aliasen (40) laden: so werden Definitionen aus dem Vault
# (Funktionen/Aliase) von unseren eigenen Aliasen in 40 überschrieben —
# wie bisher in der monolithischen .zshrc auch.
# ══════════════════════════════════════════════════════════════════════

# git yolo alias (adds all, commits with random message, force pushes to main)
if command -v git &>/dev/null && ! git config --global --get alias.yolo &>/dev/null; then
  git config --global alias.yolo '!git add -A && git commit -am "$(curl -sL http://whatthecommit.com/index.txt)" && git push -f origin main'
fi

if command -v git &>/dev/null && ! git config --global --get alias.conflicts &>/dev/null; then
  git config --global alias.conflicts '!rg -n --hidden -g "!.git" "^(<<<<<<< .*|=======|>>>>>>> .*)$"'
fi

# Enable git rerere if not already enabled
if [ "$(git config --global --get rerere.enabled)" != "true" ]; then
  git config --global rerere.enabled true
fi

# Vault — encrypted secret manager (replaces plaintext .tokens)
# Direkt aus dem vault-Repo gesourced, kein Symlink: folgt so automatisch
# $PROJECTS_DIR. Fehlt das Repo (frische Maschine), passiert einfach nichts.
[ -f "$PROJECTS_DIR/vault/zsh/vault.zsh" ] && source "$PROJECTS_DIR/vault/zsh/vault.zsh"
