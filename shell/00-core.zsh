# ══════════════════════════════════════════════════════════════════════
# 00-core.zsh — zsh-Grundsetup: Reload-Guard, Completions, History,
#               Optionen, Keybindings, Prompt.
# MUSS als erstes geladen werden (definiert u. a. _zshrc_once und compinit,
# die alle späteren Module voraussetzen).
# ══════════════════════════════════════════════════════════════════════
ZSH_PLUGINS="$HOME/.zsh/plugins"

# --- Reload guard ----------------------------------------------------
# `source ~/.zshrc` in a running shell would load the plugins below a second
# time. They wrap every ZLE widget on load and stack a new wrapper on top of
# the old one instead of replacing it — after which Tab silently does nothing.
# Blocks marked with _zshrc_once therefore run on first load only.
# For a real reload (new plugin, changed keybinding): exec zsh
typeset -gA _ZSHRC_LOADED
_zshrc_once() {
  (( ${+_ZSHRC_LOADED[$1]} )) && return 1
  _ZSHRC_LOADED[$1]=1
  return 0
}
(( ${+_ZSHRC_SOURCED} )) && print -u2 \
  "zshrc: re-sourced — ZLE plugins kept from first load. Use 'exec zsh' to reload them."
typeset -g _ZSHRC_SOURCED=1

# --- Completions in fpath aufnehmen (MUSS vor compinit passieren) ---
fpath=("$HOME/.zsh/completions" $fpath)

# --- compinit: EINMAL, mit Tages-Cache -------------------------------
# Fix fürs alte Problem: früher lief compinit doppelt (omz + eigener Aufruf).
# Jetzt genau ein Aufruf; der teure Security-Audit (compaudit) nur 1x/24h.
# Guarded too: compinit re-defines the completion widgets via `zle -C`, which
# drops zsh-autosuggestions' wrappers and makes it rebind on every re-source.
autoload -Uz compinit
if _zshrc_once compinit; then
  _zcompdump="$HOME/.zcompdump"
  if [[ -n $_zcompdump(#qN.mh+24) ]]; then
    compinit -d "$_zcompdump"      # Dump älter als 24h → neu bauen (inkl. Audit)
  else
    compinit -C -d "$_zcompdump"   # Dump frisch → nur laden, kein Audit (schnell)
  fi
  unset _zcompdump
fi

autoload -Uz edit-command-line
zle -N edit-command-line

clear-keep-buffer() {
    zle clear-screen
}
zle -N clear-keep-buffer

# --- History (Parität zu omz lib/history.zsh) ------------------------
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=10000
setopt extended_history hist_expire_dups_first hist_ignore_dups \
       hist_ignore_space hist_verify inc_append_history share_history

# --- Sinnvolle Shell-Optionen (Parität zu omz lib/directories.zsh) ---
setopt auto_cd auto_pushd pushd_ignore_dups pushdminus
setopt interactive_comments   # '#'-Kommentare auf der Kommandozeile erlaubt
setopt ignoreeof              # Ctrl-D schließt die Shell nicht sofort

# --- Completion-Styles (Parität zu omz lib/completion.zsh) -----------
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' menu select
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' special-dirs true
zstyle ':completion:*' rehash true
zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#)*=0=01;31'

# --- Keybindings (emacs + Home/End/Del + präfix-basierte History-Suche) ---
bindkey -e
bindkey '^[[H'    beginning-of-line
bindkey '^[[F'    end-of-line
bindkey '^[[3~'   delete-char
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
# Guarded: a second `zle -N` would replace zsh-autosuggestions' wrapper around
# these widgets, making it rebind everything under a fresh bindcount.
if _zshrc_once history-search-widgets; then
  zle -N up-line-or-beginning-search
  zle -N down-line-or-beginning-search
fi
bindkey '^[[A' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search

# edit-command-line: aktuelles Kommando im $EDITOR (nvim) öffnen.
# MUSS nach `bindkey -e` stehen — sonst setzt `-e` die emacs-Keymap
# zurück und wirft die Binding wieder raus.
bindkey '^x^e' edit-command-line
bindkey '^Xl' clear-keep-buffer
bindkey -s '^Xgc' 'git commit -m ""\C-b'

# --- Prompt: robbyrussell-Look via vcs_info, für große Repos entschärft ---
# vcs_info liefert nur den Branch-Namen (liest .git/HEAD — KEIN Working-Tree-
# Scan). Der Dirty-Marker (✗) kommt separat aus einem einzigen `git status
# --porcelain`, das modified, staged UND untracked abdeckt. Ignorierte
# Verzeichnisse (node_modules!) überspringt git ohne Rekursion, und
# core.untrackedCache=true ist global gesetzt.
#
# Do NOT add --no-optional-locks here. It suppresses the index writeback that
# persists the untracked cache, so the prompt can never build the cache it
# relies on and rescans the full working tree every time: measured 198ms vs
# 5ms in a 55k-file repo. A concurrent index.lock is not a reason to add it —
# the writeback is best-effort and git skips it silently (exit 0, correct
# output) when another session holds the lock.
#
# add-zsh-hook wird hier autoloaded und steht damit allen späteren Modulen
# (osc7, node_modules/.bin, …) zur Verfügung.
autoload -Uz add-zsh-hook vcs_info
zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:git:*' check-for-changes false
zstyle ':vcs_info:git:*' formats       ' %F{blue}git:(%F{red}%b%F{blue})%f'
zstyle ':vcs_info:git:*' actionformats ' %F{blue}git:(%F{red}%b%F{blue})%f %F{yellow}%a%f'

_vcs_prompt() {
  vcs_info
  _git_dirty=''
  if [[ -n $vcs_info_msg_0_ ]]; then
    if [[ -n $(command git status --porcelain \
                 --untracked-files=normal --ignore-submodules=dirty \
                 2>/dev/null | head -1) ]]; then
      _git_dirty=' %F{yellow}%1{✗%}%f'
    fi
  fi
}
add-zsh-hook precmd _vcs_prompt
setopt prompt_subst
PROMPT='%F{cyan}%~%f${vcs_info_msg_0_}${_git_dirty} '
