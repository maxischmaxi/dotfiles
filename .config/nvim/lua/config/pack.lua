vim.pack.add({
	"https://github.com/nvim-telescope/telescope.nvim",
	"https://github.com/nvim-lua/plenary.nvim",
	"https://github.com/nvim-telescope/telescope-fzf-native.nvim",
	"https://github.com/nvim-treesitter/nvim-treesitter",
	"https://github.com/nvim-treesitter/nvim-treesitter-textobjects",
	"https://github.com/nvim-treesitter/nvim-treesitter-context",
	"https://github.com/windwp/nvim-ts-autotag",
	"https://github.com/kylechui/nvim-surround",
	"https://github.com/rhysd/conflict-marker.vim",
	"https://github.com/windwp/nvim-autopairs",
	"https://github.com/MagicDuck/grug-far.nvim",
	"https://github.com/stevearc/conform.nvim",
	"https://github.com/folke/tokyonight.nvim",
	"https://github.com/neovim/nvim-lspconfig",
	"https://github.com/mason-org/mason.nvim",
	"https://github.com/WhoIsSethDaniel/mason-tool-installer.nvim",
	"https://github.com/b0o/SchemaStore.nvim",
	"https://github.com/rafamadriz/friendly-snippets",
	"https://github.com/folke/lazydev.nvim",
	-- "*" resolves to the highest published tag, so this tracks the latest release
	{ src = "https://github.com/saghen/blink.cmp", version = vim.version.range("*") },
	"https://github.com/nvim-tree/nvim-web-devicons",
	"https://github.com/nvim-lualine/lualine.nvim",
	"https://github.com/lewis6991/gitsigns.nvim",
	"https://github.com/Wansmer/treesj",
	"https://github.com/tpope/vim-fugitive",
	"https://github.com/mg979/vim-visual-multi",
	"https://github.com/derektata/lorem.nvim",
	"https://github.com/maxischmaxi/inc-select.nvim",
	"https://github.com/MunifTanjim/nui.nvim",
	"https://github.com/folke/noice.nvim",
	-- debugging: nvim-nio is a hard dependency of dap-ui
	"https://github.com/mfussenegger/nvim-dap",
	"https://github.com/nvim-neotest/nvim-nio",
	"https://github.com/rcarriga/nvim-dap-ui",
	"https://github.com/theHamsta/nvim-dap-virtual-text",
	"https://github.com/leoluz/nvim-dap-go",
})

-- only pulled in when it is the selected file explorer, see config.explorer
if vim.g.file_explorer == "oil" then
	vim.pack.add({ "https://github.com/stevearc/oil.nvim" })
end

local hooks = function(ev)
	local name, kind = ev.data.spec.name, ev.data.kind

	if name == "telescope-fzf-native.nvim" and (kind == "install" or kind == "update") then
		if vim.fn.executable("make") == 1 then
			vim.system({ "make" }, { cwd = ev.data.path })
		else
			vim.notify("make not found: telescope-fzf-native.nvim not built", vim.log.levels.WARN)
		end
	end
end

vim.api.nvim_create_autocmd("PackChanged", { callback = hooks })

vim.api.nvim_create_user_command("PackUpdate", function(info)
	if #info.fargs ~= 0 then
		vim.pack.update(info.fargs, { force = info.bang })
	else
		vim.pack.update(nil, { force = info.bang })
	end
end, {
	desc = "Update packages",
	nargs = "*",
	bang = true,
})