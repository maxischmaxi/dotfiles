#!/usr/bin/env bash
# One-time git setup per machine: aliases + rerere. Idempotent, safe to re-run.
# Used to run from the zshrc on every shell start; git config is persistent,
# so once is enough.
set -euo pipefail

# yolo: add everything, commit with a random message, force push to main
git config --global alias.yolo '!git add -A && git commit -am "$(curl -sL http://whatthecommit.com/index.txt)" && git push -f origin main'
git config --global alias.conflicts '!rg -n --hidden -g "!.git" "^(<<<<<<< .*|=======|>>>>>>> .*)$"'
git config --global rerere.enabled true

echo "git aliases + rerere configured"
