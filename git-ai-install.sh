if ! command -v git &>/dev/null; then
  echo "Git ist nicht installiert oder nicht verfügbar."
  exit 1
fi

if [[ "$EUID" -eq 0 ]]; then
  flag="system"
else
  flag="global"
fi

if git config --get alias.ai &>/dev/null || \
   git config --global --get alias.ai &>/dev/null; then
else
  cmd='git add -A && ~/.config/dotfiles/bin/commit-message.sh'
  git config --"$flag" alias.ai \!"$cmd"
fi
