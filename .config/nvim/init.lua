-- Max's neovim config, aufgeteilt nach Themen.
-- Reihenfolge matters: options vor pack (mapleader/VM_maps muessen gesetzt
-- sein, bevor die Plugins geladen werden), lsp haengt von blink.cmp ab.

require("config.options")
require("config.pack")

require("config.keymaps")
require("config.autocmds")

require("config.ui")
require("config.explorer")
require("config.editing")
require("config.telescope")
require("config.treesitter")
require("config.git")
require("config.format")
require("config.lsp")
require("config.dap")