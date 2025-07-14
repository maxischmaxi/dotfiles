if ! command -v git &>/dev/null; then
  echo "Git ist nicht installiert oder nicht verfügbar."
  exit 1
fi

if [[ "$EUID" -eq 0 ]]; then
  flag="system"
else
  flag="global"
fi

if git config --get alias.yolo &>/dev/null || \
   git config --global --get alias.yolo &>/dev/null; then
else
  cmd='git add -A && git commit -am "`curl -sL http://whatthecommit.com/index.txt`" && git push -f origin main'
  git config --"$flag" alias.yolo \!"$cmd"
fi
