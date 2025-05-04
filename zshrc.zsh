export GOPATH="$HOME/go"
export GOROOT="$(brew --prefix golang)/libexec"

export PATH="$PATH:/Users/max/Library/Python/3.9/bin"
export PATH="$PATH:/opt/homebrew/bin"
export PATH="$PATH:$HOME/go/bin"
export PATH="$PATH:$PWD/node_modules/.bin"
export PATH="$PATH:$HOME/emsdk"
export PATH="$PATH:$HOME/emsdk/upstream/emscripten"
export PATH="$PATH:/Library/TeX/texbin"
export PATH="$PATH:$HOME/depot_tools"
export PATH="$PATH:$(go env GOPATH)/bin"
export PATH="$PATH:$HOME/.config/dotfiles/bin"

export HOMEBREW_NO_ENV_HINTS=1
export DYLD_LIBRARY_PATH="/usr/local/lib:$DYLD_LIBRARY_PATH"

source $HOME/.config/git-yolo/install.sh
source $HOME/.config/dotfiles/.tokens

alias chrome="/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome"
alias oldvim="vim"
alias vim="nvim"
alias vi="nvim"
alias v="nvim"
alias gs="git status"
alias gc="git commit"
alias ga="git add"
alias gca="git commit -a"
alias ca="calendar-export"
alias python="/opt/homebrew/bin/python3"

. $HOMEBREW_PREFIX/etc/profile.d/z.sh

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

if [ -z "$TMUX" ]; then
  tmux attach || tmux new
fi
