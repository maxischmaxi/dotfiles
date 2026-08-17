# ══════════════════════════════════════════════════════════════════════
# zsh core setup  (ehemals oh-my-zsh — jetzt nativ, schlank & schnell)
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

# --- fzf-tab (NACH compinit, VOR zsh-syntax-highlighting laden) -------
_zshrc_once fzf-tab && source "$ZSH_PLUGINS/fzf-tab/fzf-tab.plugin.zsh"
# Build the fzf query only from the common candidate prefix, never from $PREFIX.
# carapace-driven completions leave the directory part in $PREFIX (they set no
# hpre), so fzf would filter "~/Downloads/" against bare basenames -> "0/3".
zstyle ':fzf-tab:*' query-string prefix
# (zsh-syntax-highlighting wird ganz am DATEIENDE geladen — Pflicht laut Doku)
# ══════════════════════════════════════════════════════════════════════

# unique the PATH entries
typeset -U PATH path

# --- nvm: LAZY (spart ~185ms Startup) --------------------------------
# Default-Node (v24) sofort & billig in den PATH → node/npm/npx sind überall
# genau wie bisher (auch in Subprozessen), OHNE nvm.sh beim Start zu sourcen.
# Das schwere nvm.sh wird erst geladen, wenn du `nvm ...` tatsächlich aufrufst.
export NVM_DIR="$HOME/.config/nvm"
if [[ -r "$NVM_DIR/alias/default" ]]; then
  _nvm_def="$(<"$NVM_DIR/alias/default")"
  _nvm_bin=("$NVM_DIR/versions/node/${_nvm_def}"*/bin(Nn))
  (( ${#_nvm_bin} )) && path=("${_nvm_bin[-1]}" $path)
  unset _nvm_def _nvm_bin
fi
nvm() {                       # Lazy-Stub: erster Aufruf lädt das echte nvm
  unset -f nvm
  [ -s /usr/share/nvm/init-nvm.sh ] && source /usr/share/nvm/init-nvm.sh
  rehash
  nvm "$@"
}

. "$HOME/.local/share/../bin/env"

# --- PROJECTS_DIR: wo die Code-Projekte liegen -----------------------
# Single Source of Truth (siehe ~/dotfiles/projects-dir.sh). Muss vor
# allem stehen, was Projektpfade braucht (vault, tmux-sessionizer).
source "$HOME/dotfiles/projects-dir.sh"

export ANDROID_HOME="$HOME/Android/Sdk/"

# --- Locale ----------------------------------------------------------
# Bewusst leer: die System-Locale kommt aus /etc/locale.conf (en_US.UTF-8) und
# gilt damit fuer Terminal- UND GUI-Apps gleich. Frueher hat dieser Block sie
# hier auf de_DE ueberschrieben — Ergebnis waren deutsche CLI-Tools und
# englische GUI-Apps. Das Tastaturlayout haengt NICHT daran, das steht in
# /etc/vconsole.conf und in kb_layout (hypr/hyprland.lua).

# --- NVIDIA / GPU ---
export GBM_BACKEND="nvidia-drm"
export __GLX_VENDOR_LIBRARY_NAME="nvidia"
export __GL_GSYNC_ALLOWED=0
export __GL_VRR_ALLOWED=1
export WLR_NO_HARDWARE_CURSORS=1
export LIBVA_DRIVER_NAME="nvidia"
export __VK_LAYER_NV_optimus="NVIDIA_only"
export PATH="/home/max/.lmstudio/bin:$PATH"

# --- Wayland / Session ---
export XDG_SESSION_TYPE="wayland"
export XDG_DATA_DIRS="/usr/share:usr/local/share:$HOME/.local/share"

# Compositor-Erkennung: Sway setzt SWAYSOCK, Hyprland setzt HYPRLAND_INSTANCE_SIGNATURE
if [[ -n "$HYPRLAND_INSTANCE_SIGNATURE" ]]; then
  export XDG_CURRENT_DESKTOP="Hyprland"
  export HYPRCURSOR_SIZE=24
elif [[ -n "$SWAYSOCK" ]]; then
  export XDG_CURRENT_DESKTOP="sway"
fi

# --- Qt / Cursor ---
export QT_QPA_PLATFORM="wayland;xcb"
export QT_QPA_PLATFORMTHEME="qt5ct"
export QT_STYLE_OVERRIDE="kvantum"
export XCURSOR_SIZE=24

export PNPM_HOME="$HOME/.local/share/pnpm"

export JAVA_HOME="/usr/lib/jvm/java-17-openjdk"
export INSTALL4J_JAVA_HOME="$JAVA_HOME"

export PATH="$PATH:$ANDROID_HOME/emulator"
export PATH="$PATH:$ANDROID_HOME/platform-tools"
export PATH="$PATH:$HOME/.cargo/bin"

alias godot="$HOME/.local/bin/godot_v4_5_1"
alias meet="meet-participants | wl-copy"
alias tg="telegramtui"
# ssh-Wrapper nur in Ghostty: 'ghostty +ssh' installiert Ghosttys terminfo auf
# dem Remote-Host. In anderen Terminals (oder auf einem Remote selbst) normalen
# ssh nutzen. $GHOSTTY_RESOURCES_DIR wird von der Shell-Integration gesetzt und
# von tmux durchgereicht — anders als $TERM, das tmux überschreibt.
if [[ -n "$GHOSTTY_RESOURCES_DIR" ]]; then
  alias ssh='ghostty +ssh --'
fi

# case ":$PATH:" in
#     *":$PNPM_HOME:"*) ;;
#     *) export PATH="$PNPM_HOME:$PATH" ;;
# esac

if [[ -d "$HOME/go" ]]; then
    export GOPATH="$HOME/go"
    export GOPRIVATE=github.com/maxischmaxi/*
    export GOROOT="/usr/lib/go"
    # Go-Cache auf die grosse Platte, wenn es sie gibt — sonst Go-Default
    # (~/.cache/go-build). Ohne Guard wuerde Go auf einer Maschine ohne
    # /stuff bei jedem Build auf ein nicht existierendes Verzeichnis zeigen.
    [[ -d /stuff/cache ]] && export GOCACHE="/stuff/cache/go-build"
    export PATH="$PATH:$HOME/go/bin"
fi

# node_modules/.bin des aktuellen Projekts — dynamisch, per chpwd.
# Vorher stand hier `PATH=$PATH:$PWD/node_modules/.bin`: $PWD wurde EINMAL
# beim Shell-Start aufgeloest und blieb dann eingefroren (im PATH hingen
# dauerhaft Pfade wie ~/node_modules/.bin, die es gar nicht gibt).
# Sucht aufwaerts, damit es auch aus Unterordnern greift, und stellt den
# Treffer VORNE an: die Projektversion von prettier/tsc/tailwindcss gewinnt
# gegen eine global installierte. Wer das nicht will, haengt ihn hinten an.
_nm_bin=""
_nm_bin_update() {
  local dir="$PWD" found=""
  while [[ -n "$dir" && "$dir" != "/" ]]; do
    if [[ -d "$dir/node_modules/.bin" ]]; then found="$dir/node_modules/.bin"; break; fi
    dir="${dir:h}"
  done
  [[ "$found" == "$_nm_bin" ]] && return
  [[ -n "$_nm_bin" ]] && path=("${(@)path:#$_nm_bin}")
  [[ -n "$found" ]] && path=("$found" $path)
  _nm_bin="$found"
}
add-zsh-hook chpwd _nm_bin_update
_nm_bin_update

# LSPs/Linter aus nvims Mason auch in der Shell (gopls, golangci-lint,
# prettierd, eslint_d, stylua ...). Ans ENDE, damit System-Pakete gewinnen —
# Mason bringt z.B. ein eigenes jq mit, das hier nicht das System-jq verdecken soll.
[[ -d "$HOME/.local/share/nvim/mason/bin" ]] && export PATH="$PATH:$HOME/.local/share/nvim/mason/bin"

export PATH="$PATH:$HOME/emsdk"
export PATH="$PATH:$HOME/emsdk/upstream/emscripten"
export PATH="$PATH:$HOME/.npm-global/bin"
export PATH="$PATH:$HOME/mongodb/bin"
export PATH="$PATH:$HOME/dotfiles"
export PATH="$PATH:$HOME/.local/bin"
export PATH="$PATH:$HOME/flutter/bin"
export PATH="$PATH:$HOME/Odin"

if [[ -d "$HOME/.deno/bin" ]]; then
    export PATH="$PATH:$HOME/.deno/bin"
fi

if [[ -d "$HOME/depot_tools" ]]; then
    export PATH="$PATH:$HOME/depot_tools"
fi

# bun completions
[ -s "/home/max/.bun/_bun" ] && source "/home/max/.bun/_bun"

# bun
if [[ -d "$HOME/.bun" ]]; then
    export BUN_INSTALL="$HOME/.bun"
    export PATH="$BUN_INSTALL/bin:$PATH"
fi

if [[ -d "$HOME/.lmstudio/bin" ]]; then
    export PATH="$PATH:$HOME/.lmstudio/bin"
fi

export ENV=development
export EDITOR="nvim"

export DYLD_LIBRARY_PATH="/usr/local/lib:$DYLD_LIBRARY_PATH"

# git yolo alias (adds all, commits with random message, force pushes to main)
if command -v git &>/dev/null && ! git config --global --get alias.yolo &>/dev/null; then
  git config --global alias.yolo '!git add -A && git commit -am "$(curl -sL http://whatthecommit.com/index.txt)" && git push -f origin main'
fi

if command -v git &>/dev/null && ! git config --global --get alias.conflicts &>/dev/null; then
  git config --global alias.conflicts '!rg -n --hidden -g "!.git" "^(<<<<<<< .*|=======|>>>>>>> .*)$"'
fi

# Enable git rerere if not already enabled
if [ "$(git config --global --get rerere.enabled)" != "true" ]; then
  git config --global rerere.enabled true
fi

# Vault — encrypted secret manager (replaces plaintext .tokens)
# Direkt aus dem vault-Repo gesourced, kein Symlink: folgt so automatisch
# $PROJECTS_DIR. Fehlt das Repo (frische Maschine), passiert einfach nichts.
[ -f "$PROJECTS_DIR/vault/zsh/vault.zsh" ] && source "$PROJECTS_DIR/vault/zsh/vault.zsh"

alias oldvim="vim"
alias vim="nvim"
alias vi="nvim"
alias v="nvim"
# Bilder im Terminal. War `wezterm imgcat` — das spricht das iTerm2-Protokoll,
# Ghostty kann aber das Kitty-Graphics-Protokoll. chafa erkennt das Terminal
# selbst und waehlt das passende. Braucht `pacman -S chafa`.
alias icat="chafa"

# eza — fancy ls replacement
alias ls='eza --icons --group-directories-first'
alias l='eza -lh --icons --git --group-directories-first'
alias la='eza -lah --icons --git --group-directories-first'
alias lt='eza --tree --level=2 --icons --group-directories-first'

alias claude="claude --dangerously-skip-permissions --effort=xhigh"

# OSC 7 — reports the current directory to the terminal.
# Ghostty uses it for "new tab/split in the same directory", and tmux keeps
# pane_current_path in sync from it (used by `bind c` / `bind v`).
_osc7_cwd() {
  printf '\e]7;file://%s%s\e\\' "${HOST}" "${PWD}"
}
add-zsh-hook chpwd _osc7_cwd
_osc7_cwd  # Report on shell startup

# Kein tmux-Autostart auf der Linux-Konsole (TERM=linux): Compositors wie
# rift brauchen das VT als Controlling-TTY — unter tmux sind VT-ioctls
# (Keyboard-Mute, VT-Switch) mit EPERM gesperrt und Input leakt ins TTY.
if [ -z "$TMUX" ] && [ -z "$INSIDE_EMACS" ] && [ -z "$VSCODE_INJECTION" ] && [ "$TERM" != "linux" ]; then
  exec tmux new-session -A -s main
fi


# fzf keybindings (nach dem tmux-exec, damit fzf Tab nicht wieder überschreibt)
# Both steps share one guard: re-running enable-fzf-tab would wrap Tab twice.
if _zshrc_once fzf; then
  [ -f $HOME/dotfiles/fzf.zsh ] && source $HOME/dotfiles/fzf.zsh

  # Re-enable fzf-tab after fzf (fzf overrides Tab binding)
  if (( $+functions[enable-fzf-tab] )); then
    enable-fzf-tab
  fi
fi

# atuin: MUSS nach fzf kommen, damit atuins Ctrl+R gewinnt.
# Bindet auch Pfeil-hoch (ersetzt up-line-or-beginning-search von oben).
_zshrc_once atuin && eval "$(atuin init zsh)"

# Projekt-Sessionizer (fuzzy über /stuff/programming, create-if-missing).
# Funktioniert in tmux (switch-client) wie außerhalb (attach). Siehe ~/dotfiles/tmux-sessionizer
# Nur noch über tmux prefix (Ctrl-a) + f — Ctrl-f-Shellbinding deaktiviert.
# bindkey -s '^f' 'tmux-sessionizer\n'

# Chronos — lazydocker auf QA/Prod VMs via SSH-forwarded docker.sock.
# (DOCKER_HOST=ssh:// hängt bei lazydocker — Unix-Socket-Forward ist stabil.)
_chronos_lazydocker() {
  local host="$1" sock="$2"
  rm -f "$sock"
  ssh -fnNT -o ExitOnForwardFailure=yes -L "$sock:/var/run/docker.sock" "root@$host" || {
    echo "SSH-Forward nach $host fehlgeschlagen" >&2
    return 1
  }
  DOCKER_HOST="unix://$sock" lazydocker
  pkill -f "ssh.*$sock" 2>/dev/null
  rm -f "$sock"
}
chronos-qa()   { _chronos_lazydocker 116.203.119.218 /tmp/docker-qa.sock }
chronos-prod() { _chronos_lazydocker 116.203.57.55  /tmp/docker-prod.sock }

# killapp — laufende Apps (nach RAM gruppiert) interaktiv beenden. Tray-Ersatz
# ohne Waybar. TAB = mehrere wählen · ENTER = beenden · ESC = abbrechen.
# Beendet nur den HAUPTprozess jeder App (der, dessen Parent NICHT zur App
# gehört) und lässt ihn seine Kindprozesse selbst sauber schließen. Sonst hängen
# sich manche Electron-Apps (z. B. teams-for-linux) auf, wenn man alle Prozesse
# gleichzeitig killt — der Hauptprozess wartet dann auf schon tote Kinder.
killapp() {
  local sel
  sel=$(ps -eo rss=,comm= \
    | awk '{rss=$1; $1=""; sub(/^ +/,""); c=$0
            if (c ~ /^(Hyprland|fzf|awk|sort|ps|sed|cut|xargs)$/) next
            a[c]+=rss; n[c]++}
           END {for (k in a) printf "%d\t%s\t%d\n", a[k], k, n[k]}' \
    | sort -rn \
    | awk -F'\t' '{printf "%-18s\t%6d MB\t%d Prozess(e)\n", $2, $1/1024, $3}' \
    | fzf --multi --delimiter='\t' --with-nth=1,2,3 \
          --header='TAB=mehrere · ENTER=beenden · ESC=abbrechen' \
    | cut -f1 | sed 's/[[:space:]]*$//')
  [[ -z "$sel" ]] && return
  local app pid ppid pcomm roots
  while IFS= read -r app; do
    [[ -z "$app" ]] && continue
    roots=""
    # Root-Prozesse sammeln (Parent gehört nicht zur App), solange noch alle leben
    for pid in ${(f)"$(pgrep -x -- "$app")"}; do
      ppid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
      [[ -z "$ppid" ]] && continue
      pcomm=$(ps -o comm= -p "$ppid" 2>/dev/null)
      [[ "$pcomm" != "$app" ]] && roots+="$pid "
    done
    if [[ -n "$roots" ]]; then
      echo "killapp: SIGTERM → $app (Hauptprozess ${roots% })"
      kill -TERM ${=roots} 2>/dev/null
    else
      echo "killapp: $app nicht (mehr) gefunden"
    fi
  done <<< "$sel"
}

# zoxide must be initialized at the very end of this file so that nothing
# else can clobber chpwd_functions and trigger __zoxide_doctor warnings.
export _ZO_DOCTOR=0
_zshrc_once zoxide && eval "$(zoxide init zsh --cmd cd)"

# Added by LM Studio CLI tool (lms)
export PATH="$PATH:/home/max/.lmstudio/bin"

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
# Kein Konflikt mit atuin — das sitzt auf Ctrl+R und Pfeil-hoch.
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

# kimi-code
export PATH="/home/max/.kimi-code/bin:$PATH"
