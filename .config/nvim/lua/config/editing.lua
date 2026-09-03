local set = vim.keymap.set

require("lorem").opts({
	sentence_length = "mixed", -- using a default configuration
	comma_chance = 0.3, -- 30% chance to insert a comma
	max_commas = 2, -- maximum 2 commas per sentence
	debounce_ms = 200, -- default debounce time in milliseconds
})

local npairs = require("nvim-autopairs")
local Rule = require("nvim-autopairs.rule")

npairs.setup({
	check_ts = true,
	enable_check_bracket_line = false,
	disable_filetype = { "TelescopePrompt", "grug-far" },
	ts_config = {
		lua = { "string" },
		javascript = { "template_string" },
		javascriptreact = { "template_string" },
		typescript = { "template_string" },
		typescriptreact = { "template_string" },
	},
})

local ts_conds = require("nvim-autopairs.ts-conds")
npairs.add_rules({
	Rule("%", "%", "lua"):with_pair(ts_conds.is_ts_node({ "string", "comment" })),
	Rule("$", "$", "lua"):with_pair(ts_conds.is_not_ts_node({ "function" })),
})

require("nvim-ts-autotag").setup()
require("nvim-surround").setup()

set("n", "<leader>m", function()
	require("treesj").toggle()
end, { desc = "[M]erge or [S]plit code block" })
set("n", "<leader>M", function()
	require("treesj").toggle({ split = { recursive = true } })
end, { desc = "[M]erge or [S]plit code block (force split)" })

require("grug-far").setup({
	-- ripgrep is already a hard dependency of telescope's live_grep here
	engine = "ripgrep",
	windowCreationCommand = "tabnew %",
})

set("n", "<leader>sw", function()
	require("grug-far").open()
end, { desc = "[S]earch and replace [W]orkspace" })
set("n", "<leader>sW", function()
	require("grug-far").open({ prefills = { search = vim.fn.expand("<cword>") } })
end, { desc = "[S]earch and replace [W]ord under cursor" })
set("v", "<leader>sw", function()
	require("grug-far").with_visual_selection()
end, { desc = "[S]earch and replace visual selection" })
set("n", "<leader>sb", function()
	require("grug-far").open({ prefills = { paths = vim.fn.expand("%") } })
end, { desc = "[S]earch and replace in current [B]uffer" })

local word_highlight = require("custom.word_highlight")
word_highlight.setup()
set("n", "<leader>hw", word_highlight.toggle, { desc = "[H]ighlight [W]ord toggle" })

require("custom.char_jump").setup()

require("custom.csv_columns").setup()

require("inc-select").setup()

require("custom.auto_set_tabstop")