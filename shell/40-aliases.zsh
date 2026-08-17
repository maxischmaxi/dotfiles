# ══════════════════════════════════════════════════════════════════════
# 40-aliases.zsh — Shell-Aliase.
# ══════════════════════════════════════════════════════════════════════

alias godot="$HOME/.local/bin/godot_v4_5_1"
alias meet="meet-participants | wl-copy"

if [[ -n "$GHOSTTY_RESOURCES_DIR" ]]; then
  alias ssh='ghostty +ssh --'
fi

alias oldvim="vim"
alias vim="nvim"
alias vi="nvim"
alias v="nvim"
alias icat="chafa"

alias claude="claude --dangerously-skip-permissions --effort=xhigh"
