# ══════════════════════════════════════════════════════════════════════
# 20-path.zsh — PATH-Verwaltung: dedup, nvm (lazy), dynamisches
#               node_modules/.bin, Tool- & Sprach-Binaries.
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

export PATH="$PATH:$ANDROID_HOME/emulator"
export PATH="$PATH:$ANDROID_HOME/platform-tools"
export PATH="$PATH:$HOME/.cargo/bin"

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

# bun
if [[ -d "$HOME/.bun" ]]; then
    export BUN_INSTALL="$HOME/.bun"
    export PATH="$BUN_INSTALL/bin:$PATH"
fi
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

if [[ -d "$HOME/.lmstudio/bin" ]]; then
    export PATH="$PATH:$HOME/.lmstudio/bin"
fi

export PATH="$HOME/.kimi-code/bin:$PATH"
