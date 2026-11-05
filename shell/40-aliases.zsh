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
unalias claude 2>/dev/null
function claude {
	python3 -I "$HOME/dotfiles/claude-trust"
	env -u ANTHROPIC_BASE_URL "$(whence -p claude)" "$@"
}
