require("nvim-treesitter").install({
	"c",
	"cpp",
	"go",
	"lua",
	"python",
	"rust",
	"tsx",
	"javascript",
	"typescript",
	"vimdoc",
	"vim",
	"bash",
	"css",
	"gleam",
	"json",
	"html",
	-- noice highlights the search cmdline with this one
	"regex",
	-- marksman + render targets
	"markdown",
	"markdown_inline",
	-- config formats
	"ini",
	"toml",
	"yaml",
	"xml",
	"csv",
	"desktop",
	"editorconfig",
	"ssh_config",
	"hyprlang",
	-- build / tooling
	"make",
	"cmake",
	"just",
	"dockerfile",
	"terraform",
	-- git
	"gitcommit",
	"gitignore",
	"gitattributes",
	"git_config",
	"git_rebase",
	-- languages with an lsp configured below
	"odin",
	"glsl",
	"sql",
	"prisma",
	"scss",
	"asm",
	"templ",
	"gomod",
	"gosum",
})

vim.api.nvim_create_autocmd("FileType", {
	callback = function(args)
		local lang = vim.treesitter.language.get_lang(vim.bo[args.buf].filetype)
		if not (lang and vim.treesitter.language.add(lang)) then
			return
		end
		-- treesitter.start() turns off the regex syntax, so a parser without a highlights
		-- query leaves the buffer completely unhighlighted -> keep the syntax fallback
		local ok, highlights = pcall(vim.treesitter.query.get, lang, "highlights")
		if not ok or not highlights then
			return
		end
		vim.treesitter.start(args.buf, lang)
		-- Treesitter-Indent ist fuer Rust fehlerhaft (verschachtelte Struct-Literale
		-- verrutschen) -> dort Neovims eingebauten Indent (runtime/indent/rust.vim) behalten
		if vim.bo[args.buf].filetype ~= "rust" then
			vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
		end
	end,
})

require("nvim-treesitter-textobjects").setup({
	select = {
		-- "V" for linewise objects, "v" for the rest, decided per query
		lookahead = true,
		selection_modes = {
			["@function.outer"] = "V",
			["@class.outer"] = "V",
		},
		include_surrounding_whitespace = false,
	},
	move = { set_jumps = true },
})

local ts_select = function(query, group)
	return function()
		require("nvim-treesitter-textobjects.select").select_textobject(query, group or "textobjects")
	end
end

-- a=around, i=inside. f=function, c=class, a(rg)=parameter, =assignment,
-- l=loop, n=conditional, o=comment, k=call
local textobjects = {
	["af"] = { "@function.outer", "Function (outer)" },
	["if"] = { "@function.inner", "Function (inner)" },
	["ac"] = { "@class.outer", "Class (outer)" },
	["ic"] = { "@class.inner", "Class (inner)" },
	["aa"] = { "@parameter.outer", "Parameter (outer)" },
	["ia"] = { "@parameter.inner", "Parameter (inner)" },
	["al"] = { "@loop.outer", "Loop (outer)" },
	["il"] = { "@loop.inner", "Loop (inner)" },
	["an"] = { "@conditional.outer", "Conditional (outer)" },
	["in"] = { "@conditional.inner", "Conditional (inner)" },
	["ak"] = { "@call.outer", "Call (outer)" },
	["ik"] = { "@call.inner", "Call (inner)" },
	["ao"] = { "@comment.outer", "Comment (outer)" },
	["io"] = { "@comment.inner", "Comment (inner)" },
	["a="] = { "@assignment.outer", "Assignment (outer)" },
	["i="] = { "@assignment.inner", "Assignment (inner)" },
	-- not "il="/"ir=": "il" already matches the loop object and would win the timeout
	["iR"] = { "@assignment.rhs", "Assignment right-hand side" },
	["iL"] = { "@assignment.lhs", "Assignment left-hand side" },
}

for keys, spec in pairs(textobjects) do
	vim.keymap.set({ "x", "o" }, keys, ts_select(spec[1]), { desc = "Textobject: " .. spec[2] })
end

local ts_move = require("nvim-treesitter-textobjects.move")
local ts_swap = require("nvim-treesitter-textobjects.swap")

-- german layout: no [ / ] motions, same <leader>{scope}{n,p} shape as dn/dp and cn/cp
vim.keymap.set({ "n", "x", "o" }, "<leader>fn", function()
	ts_move.goto_next_start("@function.outer", "textobjects")
end, { desc = "Next function start" })
vim.keymap.set({ "n", "x", "o" }, "<leader>fp", function()
	ts_move.goto_previous_start("@function.outer", "textobjects")
end, { desc = "Previous function start" })
vim.keymap.set({ "n", "x", "o" }, "<leader>fN", function()
	ts_move.goto_next_end("@function.outer", "textobjects")
end, { desc = "Next function end" })
vim.keymap.set({ "n", "x", "o" }, "<leader>fP", function()
	ts_move.goto_previous_end("@function.outer", "textobjects")
end, { desc = "Previous function end" })
vim.keymap.set({ "n", "x", "o" }, "<leader>Cn", function()
	ts_move.goto_next_start("@class.outer", "textobjects")
end, { desc = "Next class start" })
vim.keymap.set({ "n", "x", "o" }, "<leader>Cp", function()
	ts_move.goto_previous_start("@class.outer", "textobjects")
end, { desc = "Previous class start" })

vim.keymap.set("n", "<leader>an", function()
	ts_swap.swap_next("@parameter.inner")
end, { desc = "Swap parameter with next" })
vim.keymap.set("n", "<leader>ap", function()
	ts_swap.swap_previous("@parameter.inner")
end, { desc = "Swap parameter with previous" })

require("treesitter-context").setup({
	max_lines = 4,
	multiline_threshold = 1,
	trim_scope = "outer",
	mode = "cursor",
})
vim.keymap.set("n", "<leader>tc", function()
	require("treesitter-context").toggle()
end, { desc = "[T]oggle treesitter [C]ontext" })
-- jump to the context line that scrolled off the top
vim.keymap.set("n", "<leader>tu", function()
	require("treesitter-context").go_to_context(vim.v.count1)
end, { desc = "Jump [U]p to context" })