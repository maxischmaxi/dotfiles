-- Build steps run from PackChanged. Registered before vim.pack.add(), so a
-- fresh install triggers them as well.
vim.api.nvim_create_autocmd("PackChanged", {
	group = vim.api.nvim_create_augroup("custom-pack-hooks", { clear = true }),
	callback = function(ev)
		local name, kind = ev.data.spec.name, ev.data.kind
		if kind ~= "install" and kind ~= "update" then
			return
		end

		if name == "telescope-fzf-native.nvim" then
			if vim.fn.executable("make") == 1 then
				vim.system({ "make" }, { cwd = ev.data.path })
			else
				vim.notify("make not found: telescope-fzf-native.nvim not built", vim.log.levels.WARN)
			end
		elseif name == "nvim-treesitter" then
			-- scheduled: during a fresh install the plugin is not on the rtp yet
			vim.schedule(function()
				local ts = require("nvim-treesitter")
				ts.install(require("config.parsers"))
				if kind == "update" then
					ts.update()
				end
			end)
		end
	end,
})

vim.pack.add({
	"https://github.com/nvim-telescope/telescope.nvim",
	"https://github.com/nvim-lua/plenary.nvim",
	"https://github.com/nvim-telescope/telescope-fzf-native.nvim",
	"https://github.com/nvim-telescope/telescope-ui-select.nvim",
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
	-- the debugging stack (nvim-dap, nio, dap-ui, ...) is added in config.dap on first use
})

-- only pulled in when it is the selected file explorer, see config.explorer
if vim.g.file_explorer == "oil" then
	vim.pack.add({ "https://github.com/stevearc/oil.nvim" })
end

-- vim.pack.update() defaults to every plugin on disk, so the lazily added
-- debugging plugins are covered too
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
