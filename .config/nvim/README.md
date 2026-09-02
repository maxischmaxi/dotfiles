# Max's neovim config

## Installation

1. Clone this repo to `~/.config/nvim`
2. Install Tmux `$ brew install tmux`
3. Install Github Copilot `git clone https://github.com/github/copilot.vim.git ~/.config/nvim/pack/github/start/copilot.vim`

## Keymaps

### Search Files

- `<space>sf` - Search files in the current vim directory

## File explorer

The backend is a one-line switch in `lua/config/options.lua`:

```lua
vim.g.file_explorer = "netrw"  -- or "oil"
```

`netrw` is built in, `oil` pulls oil.nvim back in (`lua/config/pack.lua` only
downloads it for that value). Restart nvim after changing it; both backends
live in `lua/config/explorer.lua` and both bind `<C-b>`.

### netrw keys

Config-specific:

- `<C-b>` - open the current file's directory, cursor on the file you came from
- `<C-b>` / `<C-c>` - back to the file you came from (inside netrw)
- `=` - refresh the listing (`<C-l>` is taken by tmux navigation)
- `g?` - the full netrw map reference (`:h netrw-quickmap`)

Built into netrw:

- `<CR>` enter directory / open file, `o` horizontal split, `v` vertical split,
  `t` new tab, `p` preview, `P` open in the previously used window
- `-` up one directory, `u` / `U` back / forward through visited directories
- `%` new file, `d` new directory, `R` rename, `D` delete
- `mf` mark file, `mt` set target directory, `mc` copy marked, `mm` move marked,
  `mu` unmark all, `mx` run a shell command on marked files
- `i` cycle thin/long/wide/tree listing, `s` sort by name/time/size, `r` reverse
- `gh` toggle dot-files, `a` cycle show/hide the hide-list
- `x` open with the system handler, `qf` file info, `mb` / `gb` bookmarks
