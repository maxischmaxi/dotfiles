-- File explorer backend: "netrw" (built-in) or "oil" (plugin).
-- Read by config.pack (whether to download oil.nvim) and config.explorer.
vim.g.file_explorer = "netrw"

vim.o.number = true
vim.o.relativenumber = false
vim.o.wrap = true
vim.o.linebreak = true
vim.o.expandtab = false
vim.o.mouse = "a"
vim.o.breakindent = true
vim.o.breakindentopt = "shift:2"
vim.o.undofile = true
vim.o.ignorecase = true
vim.o.smartcase = true
vim.o.updatetime = 250
vim.o.timeoutlen = 300
vim.o.scrolloff = 12
vim.o.foldmethod = "expr"
vim.o.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.o.foldenable = false
vim.o.foldlevel = 99
vim.o.cursorline = false
vim.o.termguicolors = true
vim.o.winborder = "rounded"
vim.o.autoindent = true
vim.o.smartindent = false
vim.o.tabstop = 4
vim.o.list = true
vim.o.listchars = "tab:→ ,lead:·,trail:·,nbsp:␣,extends:›,precedes:‹"
vim.o.swapfile = false
vim.o.inccommand = "split"
vim.o.splitright = true
vim.o.splitbelow = true
vim.o.confirm = true
vim.g.mapleader = " "
vim.o.signcolumn = "yes"
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0
vim.g.loaded_node_provider = 0
vim.g.loaded_python3_provider = 0
if vim.g.have_nerd_font == nil then
	vim.g.have_nerd_font = true
end
vim.g.maplocalleader = " "
vim.g.VM_maps = {
	["Find Under"] = "<C-v>",
	["Find Subword Under"] = "<C-v>",
}
vim.o.clipboard = "unnamedplus"

-- 80er-Ruler: colorcolumn zeichnet nur, wenn die Zeile kuerzer als 80 ist,
-- nativ in C statt per-Line-Lua in einem Decoration-Provider
vim.o.colorcolumn = "80"
