# ══════════════════════════════════════════════════════════════════════
# 70-plugins.zsh — ZLE-Plugins & Tool-Integrationen.
# Lade-Reihenfolge ist kritisch (entspricht der alten .zshrc):
#   compinit (00) → fzf-tab → fzf → zoxide → carapace →
#   zsh-autosuggestions → zsh-syntax-highlighting (ZULETZT, wrappt alle Widgets).
# ══════════════════════════════════════════════════════════════════════

# --- fzf-tab (NACH compinit, VOR zsh-syntax-highlighting laden) -------
_zshrc_once fzf-tab && source "$ZSH_PLUGINS/fzf-tab/fzf-tab.plugin.zsh"
# Build the fzf query only from the common candidate prefix, never from $PREFIX.
# carapace-driven completions leave the directory part in $PREFIX (they set no
# hpre), so fzf would filter "~/Downloads/" against bare basenames -> "0/3".
zstyle ':fzf-tab:*' query-string prefix
# (zsh-syntax-highlighting wird ganz am DATEIENDE geladen — Pflicht laut Doku)

# fzf keybindings (nach dem tmux-exec, damit fzf Tab nicht wieder überschreibt)
# Both steps share one guard: re-running enable-fzf-tab would wrap Tab twice.
if _zshrc_once fzf; then
  [ -f $HOME/dotfiles/fzf.zsh ] && source $HOME/dotfiles/fzf.zsh

  # Re-enable fzf-tab after fzf (fzf overrides Tab binding)
  if (( $+functions[enable-fzf-tab] )); then
    enable-fzf-tab
  fi
fi

# television: fuzzy finder with channels. Loaded after fzf so it owns
# Ctrl-R (history) and Ctrl-T (smart autocomplete); fzf keeps Alt-C.
# Keybindings live in ~/.config/television/config.toml.
if _zshrc_once television && command -v tv >/dev/null 2>&1; then
  eval "$(tv init zsh)"

  # Ctrl-R: keep history order (newest first) instead of ranking by match
  # score, and drop duplicates so each command shows up once.
  _tv_shell_history() {
    emulate -L zsh
    zle -I
    _disable_bracketed_paste
    local output
    output=$(history -n -1 0 | awk '!seen[$0]++' \
      | tv --no-sort --no-status-bar --inline --input "$LBUFFER")
    zle reset-prompt
    if [[ -n $output ]]; then
      RBUFFER=""
      LBUFFER=$output
    fi
    _enable_bracketed_paste
  }
  zle -N tv-shell-history _tv_shell_history
fi

# Projekt-Sessionizer (fuzzy über /stuff/programming, create-if-missing).
# Funktioniert in tmux (switch-client) wie außerhalb (attach). Siehe ~/dotfiles/tmux-sessionizer
# Nur noch über tmux prefix (Ctrl-a) + f — Ctrl-f-Shellbinding deaktiviert.
# bindkey -s '^f' 'tmux-sessionizer\n'

# zoxide must be initialized at the very end of this file so that nothing
# else can clobber chpwd_functions and trigger __zoxide_doctor warnings.
export _ZO_DOCTOR=0

# Scratch and pseudo-filesystems never earn a frecency jump — keep them out of
# the db instead of pruning them by hand later. Colon-separated globs; a bare
# path (no /*) excludes only that directory, not its children.
export _ZO_EXCLUDE_DIRS="/tmp/*:/run/*:/proc/*:/sys/*:/mnt/*:/var/tmp/*"

# `cdi` picker. The interactive list is "<score> <path>", so {2..} is the path
# (works with spaces in it). eza is optional — fall back to plain ls.
if command -v eza >/dev/null 2>&1; then
  _zo_preview='eza -1 --color=always --icons --group-directories-first {2..}'
else
  _zo_preview='ls -1 --color=always {2..}'
fi
export _ZO_FZF_OPTS="--height=45% --layout=reverse --border --preview='$_zo_preview' --preview-window=right,50%"
unset _zo_preview

_zshrc_once zoxide && eval "$(zoxide init zsh --cmd cd)"

# --- carapace: Completions fuer ~1000 CLIs (gh, glab, kubectl, docker, ...) ---
# Ergaenzt, ersetzt nicht: CARAPACE_BRIDGES laesst es auf die vorhandenen
# zsh-/bash-Completions zurueckfallen, wo es selbst keine hat. Eigene
# Completions in ~/.zsh/completions (_vault, _crush, _deno) bleiben also aktiv.
# No-Op, solange carapace-bin nicht installiert ist.
if command -v carapace >/dev/null 2>&1; then
  export CARAPACE_BRIDGES='zsh,fish,bash'
  # Leave file-heavy standard tools to zsh: its native completions quote special
  # characters correctly, set hpre for fzf-tab and cost no subprocess per Tab.
  export CARAPACE_EXCLUDES='mv,cp,rm,ls,eza,cat,mkdir,rmdir,touch,ln,chmod,chown,tar,head,tail,less,more,du,df,stat,file,wc,diff,nvim,vim,vi,rsync,unzip,zip'
  source <(carapace _carapace)
fi

# --- zsh-autosuggestions: nach allen Widget-Plugins, VOR syntax-highlighting ---
# Graue Inline-Vorhersage aus der History; Rechtspfeil oder End uebernimmt sie.
# BUFFER_MAX_SIZE verhindert Tipp-Lag bei sehr langen Zeilen.
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
if _zshrc_once autosuggestions; then
  for _zas in "$ZSH_PLUGINS/zsh-autosuggestions/zsh-autosuggestions.zsh" \
              /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh; do
    [[ -r "$_zas" ]] && { source "$_zas"; break }
  done
  unset _zas
fi

# --- zsh-syntax-highlighting: MUSS als LETZTES geladen werden ---------
# (wrappt alle zuvor definierten ZLE-Widgets — fzf, zoxide, fzf-tab etc.)
_zshrc_once syntax-highlighting && \
  source "$ZSH_PLUGINS/zsh-syntax-highlighting/zsh-syntax-highlighting.plugin.zsh"
