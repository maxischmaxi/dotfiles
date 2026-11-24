# ══════════════════════════════════════════════════════════════════════
# 40-aliases.zsh — Shell-Aliase.
# ══════════════════════════════════════════════════════════════════════

alias godot="$HOME/.local/bin/godot_v4_5_1"

alias oldvim="vim"
alias vim="nvim"
alias vi="nvim"
alias v="nvim"
alias icat="chafa"
alias l="ls -al"

# Pre-accept trust/external-includes dialogs, then start claude without the
# local proxy base url. whence -p resolves the real binary, not this function.
# Uses the private profile unless a config dir is already set.
unalias claude 2>/dev/null
function claude {
    local -x CLAUDE_CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/claude/private}"
    python3 -I "$HOME/dotfiles/claude-trust"
    env -u ANTHROPIC_BASE_URL "$(whence -p claude)" "$@"
}

function globo-claude {
    CLAUDE_CONFIG_DIR="$HOME/claude/globogate" claude "$@"
}
function gclaude {
    CLAUDE_CONFIG_DIR="$HOME/claude/globogate" claude "$@"
}

function max-claude {
    CLAUDE_CONFIG_DIR="$HOME/claude/private" claude "$@"
}
