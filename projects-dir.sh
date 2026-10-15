# PROJECTS_DIR — wo die Code-Projekte liegen.
#
# Bewusst POSIX (kein zsh-Syntax): wird sowohl von zshrc.zsh als auch von
# bash-Scripts wie tmux-sessionizer gesourced. Einziger Ort, an dem der
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

# Work projects live on their own disk.
if [ -z "${WORK_PROJECTS_DIR:-}" ] && [ -d /arbeit ]; then
    WORK_PROJECTS_DIR=/arbeit
    export WORK_PROJECTS_DIR
fi

# List projects as "<real path>\t<short display path>" for fzf pickers.
projects_list() {
    {
        find "$PROJECTS_DIR" -mindepth 1 -maxdepth 1 -type d ! -name '.*' ! -name 'lost+found' -printf '%p\t~c/%f\n'
        if [ -n "${WORK_PROJECTS_DIR:-}" ]; then
            find "$WORK_PROJECTS_DIR" -mindepth 1 -maxdepth 1 -type d ! -name '.*' ! -name 'lost+found' -printf '%p\t~arbeit/%f\n'
        fi
    } 2>/dev/null | sort -t "$(printf '\t')" -k2
}
