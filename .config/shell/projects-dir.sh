# PROJECTS_DIR — wo die Code-Projekte liegen.
#
# Bewusst POSIX (kein zsh-Syntax): wird sowohl von zshrc.zsh als auch von
# bash-Scripts wie bin/tmux-sessionizer gesourced. Einziger Ort, an dem der
# Pfad steht — vorher war er über zshrc, sessionizer und einen Symlink
# dupliziert und lief beim Umzug /code -> /stuff/programming auseinander.
#
# Auf dieser Maschine liegen die Projekte auf einer eigenen Platte
# (/stuff/programming). Wo es die nicht gibt, greift ~/projects.

if [ -z "${PROJECTS_DIR:-}" ]; then
    if [ -d /stuff/programming ]; then
        PROJECTS_DIR=/stuff/programming
    else
        PROJECTS_DIR="$HOME/projects"
    fi
    export PROJECTS_DIR
fi
