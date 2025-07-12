# dotfiles

## installation

add the following to your `~/.zshrc` file:

```sh
source $HOME/.config/dotiles/zshrc.zsh
```

## dump brew config into file for porting over to another machine

```sh
chmod +x ./bin/dump.sh
./bin/dump.sh
```

## gitconfig

run the following command to set up your git config:

```sh
envsubst < ~/.config/dotfiles/.gitconfig.template > ~/.gitconfig
```
