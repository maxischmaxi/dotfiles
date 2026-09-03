require("lualine").setup({
	options = {
		icons_enabled = true,
		theme = "tokyonight",
	},
	sections = {
		lualine_c = {
			{ "filename", path = 1 },
		},
	},
})

-- require("github-theme").setup({})
-- vim.cmd("colorscheme github_dark_default")

require("tokyonight").setup({
	transparent = true,
	styles = {
		sidebars = "transparent",
		floats = "transparent",
	},
})
vim.cmd([[ colorscheme tokyonight-night ]])

-- require("orng").setup({
-- 	italic_comment = true,
-- })
-- vim.cmd([[ colorscheme orng ]])

require("noice").setup({
	lsp = {
		-- blink.cmp renders signature help itself
		signature = { enabled = false },
		hover = { silent = true },
	},
	presets = {
		-- keep / and ? at the bottom, only : becomes the centered popup
		bottom_search = true,
		long_message_to_split = true,
	},
})

vim.g.conflict_marker_begin = "^<<<<<<<\\+ .*$"
vim.g.conflict_marker_common_ancestors = "^|||||||\\+ .*$"
vim.g.conflict_marker_end = "^>>>>>>>\\+ .*$"
vim.g.conflict_marker_highlight_group = ""

vim.cmd([[
        highlight ConflictMarkerBegin guibg=#2f7366
        highlight ConflictMarkerOurs guibg=#2e5049
        highlight ConflictMarkerTheirs guibg=#344f69
        highlight ConflictMarkerEnd guibg=#2f628e
        highlight ConflictMarkerCommonAncestorsHunk guibg=#754a81
]])