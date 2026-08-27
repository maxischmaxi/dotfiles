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
vim.o.completeopt = "menuone,noselect"
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

vim.filetype.add({ extension = { jsonc = "jsonc" } })

local set = vim.keymap.set

vim.pack.add({
	"https://github.com/stevearc/oil.nvim",
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
vim.cmd("source ~/dotfiles/tmux-navigator.lua")

vim.api.nvim_create_autocmd("TextYankPost", {
	callback = function()
		vim.hl.hl_op()
	end,
	group = vim.api.nvim_create_augroup("YankHighlight", { clear = true }),
	pattern = "*",
})

vim.api.nvim_create_autocmd("LspAttach", {
	group = vim.api.nvim_create_augroup("custom-lsp-document-color", { clear = true }),
	callback = function(ev)
		local client = vim.lsp.get_client_by_id(ev.data.client_id)
		if client and client:supports_method("textDocument/documentColor", ev.buf) then
			vim.lsp.document_color.enable(true, { bufnr = ev.buf })
		end
	end,
})

vim.api.nvim_create_autocmd("LspNotify", {
	group = vim.api.nvim_create_augroup("custom-lsp-fold-imports", { clear = true }),
	callback = function(ev)
		if ev.data.method == "textDocument/didOpen" then
			vim.lsp.foldclose("imports", vim.fn.bufwinid(ev.buf))
		end
	end,
})

set("n", "<leader>e", vim.diagnostic.open_float, { desc = "Open floating diagnostic message" })
set("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Open diagnostics list" })
set("n", "<leader>i", ":noh<CR>", { silent = true, desc = "hide search highlights" })
set("n", "<leader>dn", function()
	vim.diagnostic.jump({
		count = 1,
		severity = {
			min = vim.diagnostic.severity.INFO,
			max = vim.diagnostic.severity.ERROR,
		},
	})
end, { desc = "Next diagnostic" })
set("n", "<leader>dp", function()
	vim.diagnostic.jump({
		count = -1,
		severity = vim.diagnostic.severity.ERROR,
	})
end, { desc = "Previous diagnostic" })
set("n", "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })
set("n", "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })
set({ "n", "v" }, "<Space>", "<Nop>", { silent = true })
set("n", "n", "nzzzv")
set("n", "N", "Nzzzv")
set("n", "<c-d>", "<c-d>zz", { desc = "Scroll down half screen" })
set("n", "<c-u>", "<c-u>zz", { desc = "Scroll up half screen" })

set("n", "<leader>cn", "<cmd>cnext<CR>zz", { desc = "Go to next quickfix item" })
set("n", "<leader>cp", "<cmd>cprev<CR>zz", { desc = "Go to previous quickfix item" })

set("n", "<leader>+", ':exe "vertical resize " . (winwidth(0) * 4/1)<CR>', { silent = true })
set("n", "<leader>-", ':exe "vertical resize " . (winwidth(0) * 1/4)<CR>', { silent = true })
set("n", "<C-b>", "<CMD>Oil<CR>", { desc = "Open Oil" })

set("n", "<leader>m", function()
	require("treesj").toggle()
end, { desc = "[M]erge or [S]plit code block" })
set("n", "<leader>M", function()
	require("treesj").toggle({ split = { recursive = true } })
end, { desc = "[M]erge or [S]plit code block (force split)" })

require("lorem").opts({
	sentence_length = "mixed", -- using a default configuration
	comma_chance = 0.3, -- 30% chance to insert a comma
	max_commas = 2, -- maximum 2 commas per sentence
	debounce_ms = 200, -- default debounce time in milliseconds
})
require("gitsigns").setup({
	-- german layout: [ and ] are AltGr+8/9, so hunk navigation lives on <leader>g
	-- and follows the existing <leader>{scope}{n,p} pattern (dn/dp, cn/cp)
	on_attach = function(bufnr)
		local gs = require("gitsigns")
		local map = function(mode, keys, func, desc)
			vim.keymap.set(mode, keys, func, { buffer = bufnr, desc = "Git: " .. desc })
		end

		map("n", "<leader>gn", function()
			-- in a diff buffer the plugin has no hunks, fall back to vim's own ]c
			if vim.wo.diff then
				vim.cmd.normal({ "]c", bang = true })
			else
				gs.nav_hunk("next")
			end
		end, "Next hunk")

		map("n", "<leader>gp", function()
			if vim.wo.diff then
				vim.cmd.normal({ "[c", bang = true })
			else
				gs.nav_hunk("prev")
			end
		end, "Previous hunk")

		map("n", "<leader>gs", gs.stage_hunk, "Stage hunk")
		map("n", "<leader>gr", gs.reset_hunk, "Reset hunk")
		map("v", "<leader>gs", function()
			gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
		end, "Stage selected lines")
		map("v", "<leader>gr", function()
			gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
		end, "Reset selected lines")

		map("n", "<leader>gS", gs.stage_buffer, "Stage buffer")
		map("n", "<leader>gR", gs.reset_buffer, "Reset buffer")
		map("n", "<leader>gv", gs.preview_hunk, "Preview hunk (float)")
		map("n", "<leader>gV", gs.preview_hunk_inline, "Preview hunk (inline)")
		map("n", "<leader>gb", function()
			gs.blame_line({ full = true })
		end, "Blame line (full)")
		map("n", "<leader>gB", gs.toggle_current_line_blame, "Toggle inline blame")
		map("n", "<leader>gd", gs.diffthis, "Diff against index")
		map("n", "<leader>gD", function()
			gs.diffthis("@")
		end, "Diff against HEAD")
		map("n", "<leader>gx", gs.toggle_deleted, "Toggle deleted lines")

		-- ih = "inner hunk", works with d/y/c like any other text object
		map({ "o", "x" }, "ih", gs.select_hunk, "Select hunk")
	end,
})

-- fugitive: the status buffer is the entry point for everything gitsigns can't do
set("n", "<leader>gg", "<cmd>Git<CR>", { desc = "Git: fugitive status" })

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

require("lazydev").setup({
	library = {
		{ path = "${3rd}/luv/library", words = { "vim%.uv" } },
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

local word_highlight = require("custom.word_highlight")
word_highlight.setup()
set("n", "<leader>hw", word_highlight.toggle, { desc = "[H]ighlight [W]ord toggle" })

require("custom.char_jump").setup()

require("custom.csv_columns").setup()

require("inc-select").setup()

require("custom.auto_set_tabstop")

require("dressing").setup({
	input = {
		relative = "cursor",
		prefer_width = 60,
	},
	select = {
		backend = { "telescope", "builtin" },
	},
})

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

local npairs = require("nvim-autopairs")
local Rule = require("nvim-autopairs.rule")

npairs.setup({
	check_ts = true,
	enable_check_bracket_line = false,
	-- the dressing prompt is a one-line input buffer, pairing there is only in the way
	disable_filetype = { "TelescopePrompt", "grug-far", "snacks_picker_input", "DressingInput" },
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

require("conform").setup({
	formatters_by_ft = {
		lua = { "stylua" },
		javascript = { "prettierd" },
		typescript = { "prettierd" },
		javascriptreact = { "prettierd" },
		typescriptreact = { "prettierd" },
		json = { "prettierd" },
		jsonc = { "prettierd_json" },
		html = { "prettierd" },
		css = { "stylelint", "prettierd" },
		markdown = { "prettierd" },
		rust = { "rustfmt" },
		odin = { "odinfmt" },
		c = { "clang-format" },
		cpp = { "clang-format" },
		go = { "goimports", "gofumpt" },
		sh = { "shfmt" },
		bash = { "shfmt" },
		zsh = { "shfmt" },
		yaml = { "prettierd" },
		toml = { "taplo" },
		python = { "ruff_organize_imports", "ruff_format" },
		terraform = { "terraform_fmt" },
		hcl = { "terraform_fmt" },
		["_"] = { "trim_whitespace" },
	},
	formatters = {
		odinfmt = {
			command = "odinfmt",
			args = { "-stdin" },
			stdin = true,
		},
		prettierd_json = {
			command = "prettierd",
			args = function(_, ctx)
				return { (ctx.filename:gsub("%.jsonc$", ".json")) }
			end,
			stdin = true,
		},
	},
	format_on_save = function(bufnr)
		-- these servers format themselves; the "_" formatter would otherwise shadow them
		local lsp_formatted = { glsl = true, just = true, templ = true }
		local prefer_lsp = lsp_formatted[vim.bo[bufnr].filetype]
		return { timeout_ms = 2000, lsp_format = prefer_lsp and "prefer" or "fallback" }
	end,
})

local ns = vim.api.nvim_create_namespace("ruler80")
vim.api.nvim_set_decoration_provider(ns, {
	on_line = function(_, _, bufnr, row)
		local width = vim.fn.strdisplaywidth(vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or "")
		if width < 80 then
			-- extmark inline virt text an Spalte 80
			vim.api.nvim_buf_set_extmark(bufnr, ns, row, 0, {
				virt_text = { { "│", "Comment" } },
				virt_text_win_col = 80,
				ephemeral = true,
			})
		end
	end,
})

vim.api.nvim_create_autocmd("LspAttach", {
	callback = function(ev)
		local client = vim.lsp.get_client_by_id(ev.data.client_id)
		if client:supports_method("textDocument/codeLens", ev.buf) then
			vim.lsp.codelens.enable(true, { bufnr = ev.buf })
			vim.keymap.set("n", "<leader>cl", vim.lsp.codelens.run, { buffer = ev.buf, desc = "Run code lens" })
		end
	end,
})

vim.api.nvim_create_autocmd("BufWritePre", {
	desc = "Apply eslint --fix on save",
	pattern = { "*.js", "*.ts", "*.jsx", "*.tsx", "*.mjs", "*.cjs", "*.mts", "*.cts" },
	group = vim.api.nvim_create_augroup("FormatEslint", { clear = true }),
	callback = function(ev)
		local clients = vim.lsp.get_clients({ bufnr = ev.buf, name = "eslint" })
		if #clients == 0 then
			return
		end
		local client = clients[1]

		-- vim.lsp.buf.code_action{apply=true} is async and cannot be awaited, so the
		-- old version raced the write. Resolve the action synchronously instead.
		-- Params are built from ev.buf rather than the current window: on :wa the
		-- buffer being written is not necessarily the one on screen.
		local params = {
			textDocument = vim.lsp.util.make_text_document_params(ev.buf),
			range = {
				["start"] = { line = 0, character = 0 },
				["end"] = { line = 0, character = 0 },
			},
			context = { only = { "source.fixAll.eslint" }, diagnostics = {} },
		}

		local res = client:request_sync("textDocument/codeAction", params, 3000, ev.buf)
		if not res or res.err or not res.result then
			return
		end

		for _, action in ipairs(res.result) do
			-- eslint returns the edit inline, so no codeAction/resolve round trip needed
			if action.edit then
				vim.lsp.util.apply_workspace_edit(action.edit, client.offset_encoding)
			end
		end
	end,
})

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
	set({ "x", "o" }, keys, ts_select(spec[1]), { desc = "Textobject: " .. spec[2] })
end

local ts_move = require("nvim-treesitter-textobjects.move")
local ts_swap = require("nvim-treesitter-textobjects.swap")

-- german layout: no [ / ] motions, same <leader>{scope}{n,p} shape as dn/dp and cn/cp
set({ "n", "x", "o" }, "<leader>fn", function()
	ts_move.goto_next_start("@function.outer", "textobjects")
end, { desc = "Next function start" })
set({ "n", "x", "o" }, "<leader>fp", function()
	ts_move.goto_previous_start("@function.outer", "textobjects")
end, { desc = "Previous function start" })
set({ "n", "x", "o" }, "<leader>fN", function()
	ts_move.goto_next_end("@function.outer", "textobjects")
end, { desc = "Next function end" })
set({ "n", "x", "o" }, "<leader>fP", function()
	ts_move.goto_previous_end("@function.outer", "textobjects")
end, { desc = "Previous function end" })
set({ "n", "x", "o" }, "<leader>Cn", function()
	ts_move.goto_next_start("@class.outer", "textobjects")
end, { desc = "Next class start" })
set({ "n", "x", "o" }, "<leader>Cp", function()
	ts_move.goto_previous_start("@class.outer", "textobjects")
end, { desc = "Previous class start" })

set("n", "<leader>an", function()
	ts_swap.swap_next("@parameter.inner")
end, { desc = "Swap parameter with next" })
set("n", "<leader>ap", function()
	ts_swap.swap_previous("@parameter.inner")
end, { desc = "Swap parameter with previous" })

require("treesitter-context").setup({
	max_lines = 4,
	multiline_threshold = 1,
	trim_scope = "outer",
	mode = "cursor",
})
set("n", "<leader>tc", function()
	require("treesitter-context").toggle()
end, { desc = "[T]oggle treesitter [C]ontext" })
-- jump to the context line that scrolled off the top
set("n", "<leader>tu", function()
	require("treesitter-context").go_to_context(vim.v.count1)
end, { desc = "Jump [U]p to context" })

require("oil").setup({
	default_file_explorer = true,
	columns = {
		"icon",
		"size",
		"mtime",
	},
	buf_options = {
		buflisted = false,
		bufhidden = "hide",
	},
	win_options = {
		wrap = false,
		signcolumn = "no",
		cursorcolumn = false,
		foldcolumn = "0",
		spell = false,
		list = false,
		conceallevel = 3,
		concealcursor = "nvic",
	},
	delete_to_trash = false,
	skip_confirm_for_simple_edits = true,
	prompt_save_on_select_new_entry = true,
	cleanup_delay_ms = 2000,
	lsp_file_methods = {
		enabled = true,
		timeout_ms = 1000,
		autosave_changes = false,
	},
	constrain_cursor = "editable",
	watch_for_changes = false,
	keymaps = {
		["="] = "actions.refresh",
	},
	use_default_keymaps = true,
	view_options = {
		show_hidden = true,
	},
})

require("telescope").setup({
	defaults = {
		preview = {
			filesize_limit = 10,
			mime_hook = function(fp, bufnr, opts)
				local is_image = function(filepath)
					local image_extensions = { "png", "jpg" } -- Supported image formats
					local split_path = vim.split(filepath:lower(), ".", { plain = true })
					local extension = split_path[#split_path]
					return vim.tbl_contains(image_extensions, extension)
				end
				if is_image(fp) and vim.fn.executable("catimg") == 1 then
					local term = vim.api.nvim_open_term(bufnr, {})
					local function send_output(_, data, _)
						for _, d in ipairs(data) do
							vim.api.nvim_chan_send(term, d .. "\r\n")
						end
					end
					vim.fn.jobstart({
						"catimg",
						"-w",
						"100",
						"-r",
						"2",
						fp,
					}, {
						on_stdout = send_output,
						stdout_buffered = true,
						pty = true,
					})
				else
					local message = is_image(fp) and "catimg not found: image preview disabled"
						or "Binary cannot be previewed"
					require("telescope.previewers.utils").set_preview_message(bufnr, opts.winid, message)
				end
			end,
		},
		layout_config = { width = 0.9, height = 0.9 },
		file_ignore_patterns = {
			"node_modules/",
			"%.git/",
			"%.tsbuildinfo$",
			"__image%-snapshots__/",
			"%.o$",
			"%.a$",
			"%.out$",
			"%.obj$",
			"%.gch$",
			"%.pch$",
		},
	},
	pickers = {
		find_files = {
			hidden = true,
			find_command = {
				"rg",
				"--files",
				"--hidden",
				"--glob",
				"!**/.git/*",
			},
		},
	},
	extensions = {
		fzf = {
			fuzzy = true,
			override_generic_sorter = true,
			override_file_sorter = true,
			case_mode = "smart_case",
		},
	},
})

require("telescope").load_extension("fzf")

-- require lazily so telescope.builtin is not pulled in at startup
local pick = function(name, opts)
	return function()
		require("telescope.builtin")[name](opts)
	end
end

set("n", "<leader>sf", pick("find_files"), { desc = "[S]earch [F]iles" })
set("n", "<leader>sg", pick("live_grep"), { desc = "[S]earch by [G]rep" })
set("n", "<leader>sh", pick("help_tags"), { desc = "[S]earch [H]elp" })
set("n", "<leader>sk", pick("keymaps"), { desc = "[S]earch [K]eymaps" })
set("n", "<leader>sd", pick("diagnostics"), { desc = "[S]earch [D]iagnostics" })
set("n", "<leader>sr", pick("resume"), { desc = "[S]earch [R]esume last picker" })
set("n", "<leader>s.", pick("oldfiles"), { desc = "[S]earch recent files" })
set("n", "<leader>ss", pick("lsp_document_symbols"), { desc = "[S]earch document [S]ymbols" })
set("n", "<leader>sS", pick("lsp_dynamic_workspace_symbols"), { desc = "[S]earch workspace [S]ymbols" })
set("n", "<leader>st", pick("builtin"), { desc = "[S]earch [T]elescope pickers" })
set("n", "<leader>sc", pick("commands"), { desc = "[S]earch [C]ommands" })
set("n", "<leader>sm", pick("marks"), { desc = "[S]earch [M]arks" })
set("n", "<leader>sq", pick("quickfix"), { desc = "[S]earch [Q]uickfix list" })
set("n", "<leader>sj", pick("jumplist"), { desc = "[S]earch [J]umplist" })
set("n", "<leader><leader>", pick("buffers"), { desc = "Find existing buffers" })

-- search only inside the current buffer
set("n", "<leader>/", function()
	require("telescope.builtin").current_buffer_fuzzy_find(
		require("telescope.themes").get_dropdown({ winblend = 10, previewer = false })
	)
end, { desc = "Fuzzy search in current buffer" })

-- grep the word/selection under the cursor
set("n", "<leader>*", pick("grep_string"), { desc = "Grep word under cursor" })
set("v", "<leader>*", pick("grep_string"), { desc = "Grep visual selection" })

set("n", "<leader>gf", pick("git_status"), { desc = "Git: status picker" })
set("n", "<leader>gc", pick("git_commits"), { desc = "Git: commit log" })
set("n", "<leader>gh", pick("git_bcommits"), { desc = "Git: commits for this file" })
set("n", "<leader>gt", pick("git_branches"), { desc = "Git: branches" })

set("n", "gd", pick("lsp_definitions"), { desc = "[G]oto [D]efinition" })
set("n", "gr", pick("lsp_references"), { desc = "[G]oto [R]eferences" })
set("n", "gI", pick("lsp_implementations"), { desc = "[G]oto [I]mplementation" })
set("n", "gy", pick("lsp_type_definitions"), { desc = "[G]oto t[y]pe definition" })
set("n", "<leader>rn", vim.lsp.buf.rename, { desc = "[R]e[n]ame" })

-- K is taken by lsp hover, which only shows the declaration; gK gets the prose
set("n", "gK", function()
	local ok, err = pcall(vim.cmd, "Man " .. vim.fn.expand("<cword>"))
	if not ok then
		vim.notify(err, vim.log.levels.WARN)
	end
end, { desc = "Open man page for word under cursor" })

vim.api.nvim_create_autocmd("LspAttach", {
	group = vim.api.nvim_create_augroup("custom-lsp-attach", { clear = true }),
	callback = function(event)
		local map = function(keys, func, desc, mode)
			mode = mode or "n"
			vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = "LSP: " .. desc })
		end

		local client = vim.lsp.get_client_by_id(event.data.client_id)
		if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_documentHighlight, event.buf) then
			local highlight_augroup = vim.api.nvim_create_augroup("custom-lsp-highlight", { clear = false })
			vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
				buffer = event.buf,
				group = highlight_augroup,
				callback = vim.lsp.buf.document_highlight,
			})

			vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
				buffer = event.buf,
				group = highlight_augroup,
				callback = vim.lsp.buf.clear_references,
			})

			vim.api.nvim_create_autocmd("LspDetach", {
				group = vim.api.nvim_create_augroup("custom-lsp-detach", { clear = true }),
				callback = function(event2)
					vim.lsp.buf.clear_references()
					vim.api.nvim_clear_autocmds({
						group = "custom-lsp-highlight",
						buffer = event2.buf,
					})
				end,
			})
		end

		if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint, event.buf) then
			map("<leader>th", function()
				vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({
					bufnr = event.buf,
				}))
			end, "[T]oggle Inlay [H]ints")
		end

		if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_codeAction, event.buf) then
			map("<leader>ca", vim.lsp.buf.code_action, "[C]ode [A]ctions")
		end
	end,
})

vim.diagnostic.config({
	severity_sort = true,
	float = { border = "rounded", source = "if_many" },
	underline = { severity = vim.diagnostic.severity.ERROR },
	signs = vim.g.have_nerd_font and {
		text = {
			[vim.diagnostic.severity.ERROR] = "󰅚 ",
			[vim.diagnostic.severity.WARN] = "󰀪 ",
			[vim.diagnostic.severity.INFO] = "󰋽 ",
			[vim.diagnostic.severity.HINT] = "󰌶 ",
		},
	} or {},
	virtual_text = {
		source = "if_many",
		spacing = 2,
	},
})

local blink_cmp = require("blink.cmp")

blink_cmp.setup({
	keymap = {
		preset = "default",
		["<Up>"] = { "select_prev", "fallback" },
		["<Down>"] = { "select_next", "fallback" },

		-- show with a list of providers
		["<C-space>"] = { "show", "fallback" },
		["<CR>"] = { "fallback" },
		["<Tab>"] = { "accept", "fallback" },
	},

	appearance = {
		nerd_font_variant = "mono",
	},

	completion = {
		documentation = { auto_show = true },
		menu = {
			draw = {
				treesitter = { "lsp" },
				columns = {
					{ "kind_icon" },
					{ "label", "label_description", gap = 1 },
					{ "kind" },
				},
			},
		},
		trigger = {
			show_on_insert_on_trigger_character = true,
		},
	},

	sources = {
		default = { "lsp", "path", "snippets", "buffer" },
		min_keyword_length = 0,
		providers = {
			lsp = {
				min_keyword_length = 0,
			},
		},
	},

	fuzzy = { implementation = "prefer_rust_with_warning" },
})

local capabilities = blink_cmp.get_lsp_capabilities()

local servers = {
	ltex = {
		mason = "ltex-ls",
		settings = {
			ltex = {
				language = "de",
				enabled = { "latex", "tex", "bib" },
			},
		},
	},
	lua_ls = {
		mason = "lua-language-server",
		settings = {
			Lua = {
				completion = {
					callSnippet = "Replace",
				},
				runtime = {
					version = "LuaJIT",
				},
				diagnostics = {
					globals = { "vim" },
				},
			},
		},
	},
	cssls = { mason = "css-lsp" },
	css_variables = { mason = "css-variables-language-server" },
	cssmodules_ls = {
		mason = "cssmodules-language-server",
		-- it advertises hoverProvider but only ever answers null (it can do
		-- definition/completion, not hover). noice renders hover per client instead
		-- of aggregating, so that null became "No information available" alongside
		-- vtsls' actual type popup.
		on_attach = function(client)
			client.server_capabilities.hoverProvider = false
		end,
	},
	eslint = {
		mason = "eslint-lsp",
		settings = {
			experimental = {
				useFlatConfig = true,
			},
			workingDirectories = { mode = "auto" },
			codeActionOnSave = {
				enable = true,
				mode = "all",
			},
		},
	},
	ols = {
		mason = false,
		cmd = { "/home/max/ols/ols" },
		settings = {
			odin_command = "/home/max/Odin/odin",
		},
	},
	stylelint_lsp = { mason = "stylelint-language-server" },
	jsonls = {
		mason = "json-lsp",
		filetypes = { "json", "jsonc" },
		settings = {
			json = {
				validate = { enable = true },
				schemas = require("schemastore").json.schemas(),
			},
		},
	},
	yamlls = {
		mason = "yaml-language-server",
		settings = {
			yaml = {
				-- SchemaStore supplies the catalogue, so yamlls' own store must be off
				schemaStore = { enable = false, url = "" },
				schemas = require("schemastore").yaml.schemas(),
				validate = true,
				keyOrdering = false,
			},
		},
	},
	taplo = { mason = "taplo" },
	jqls = { mason = "jq-lsp" },
	gopls = {
		mason = "gopls",
		settings = {
			gopls = {
				gofumpt = true,
				staticcheck = true,
				usePlaceholders = true,
				analyses = {
					unusedparams = true,
					unusedwrite = true,
					nilness = true,
					shadow = true,
				},
				hints = {
					assignVariableTypes = true,
					compositeLiteralFields = true,
					constantValues = true,
					functionTypeParameters = true,
					parameterNames = true,
					rangeVariableTypes = true,
				},
			},
		},
	},
	templ = { mason = "templ" },
	html = {
		mason = "html-lsp",
		-- templ files are html + go, htmlls handles the markup half
		filetypes = { "html", "templ" },
	},
	bashls = {
		mason = "bash-language-server",
		filetypes = { "sh", "bash", "zsh" },
		settings = {
			bashIde = { shellcheckPath = "shellcheck" },
		},
	},
	dockerls = { mason = "dockerfile-language-server" },
	docker_compose_language_service = { mason = "docker-compose-language-service" },
	terraformls = { mason = "terraform-ls" },
	prismals = { mason = "prisma-language-server" },
	marksman = { mason = "marksman" },
	harper_ls = {
		mason = "harper-ls",
		-- grammar/spelling inside comments, strings and markdown; no JVM, unlike ltex
		settings = {
			["harper-ls"] = {
				linters = {
					SentenceCapitalization = false,
					SpellCheck = true,
					ToDoHyphen = false,
				},
				isolateEnglish = true,
			},
		},
		filetypes = { "markdown", "gitcommit", "text" },
	},
	basedpyright = {
		mason = "basedpyright",
		settings = {
			basedpyright = {
				analysis = {
					typeCheckingMode = "standard",
					autoImportCompletions = true,
					diagnosticMode = "openFilesOnly",
				},
			},
		},
	},
	ruff = { mason = "ruff" },
	glsl_analyzer = { mason = "glsl_analyzer" },
	just = { mason = "just-lsp" },
	tailwindcss = { mason = "tailwindcss-language-server" },
	vtsls = { mason = "vtsls" },
	clangd = {
		mason = "clangd",
		cmd = {
			"clangd",
			"--background-index",
			"--clang-tidy",
			"--completion-style=detailed",
		},
	},
	-- installed via `uv tool install --python 3.13 --with 'pygls<2' cmake-language-server`
	-- (mason's pypi installer can't build it: needs python < 3.14)
	cmake = { mason = false },
	rust_analyzer = {
		mason = "rust-analyzer",
		settings = {
			["rust-analyzer"] = {
				cargo = { allFeatures = true },
				check = { command = "clippy" },
			},
		},
	},
}

local ensure_installed = {
	"stylua",
	"prettier",
	"prettierd",
	"eslint_d",
	"stylelint",
	"jq",
	"clang-format",
	"shfmt",
	"shellcheck",
	"gofumpt",
	"goimports",
	"delve",
	"codelldb",
}

for server_name, server_config in pairs(servers) do
	if server_config.mason then
		table.insert(ensure_installed, server_config.mason)
	end
	local config = vim.tbl_deep_extend("force", {}, { capabilities = capabilities }, server_config)
	config.mason = nil
	vim.lsp.config(server_name, config)
end

require("mason").setup()
require("mason-tool-installer").setup({ ensure_installed = ensure_installed })
vim.lsp.enable(vim.tbl_keys(servers))

vim.api.nvim_create_user_command("LspRestart", function()
	local clients = vim.lsp.get_clients()
	if #clients == 0 then
		vim.notify("No active LSP clients", vim.log.levels.INFO)
		return
	end
	local names = {}
	for _, client in ipairs(clients) do
		table.insert(names, client.name)
		client:stop()
	end
	vim.defer_fn(function()
		for _, name in ipairs(names) do
			vim.lsp.enable(name)
		end
		vim.notify("Restarted: " .. table.concat(names, ", "), vim.log.levels.INFO)
	end, 500)
end, { desc = "Restart all LSP clients" })

vim.lsp.config("wcag_lsp", {
	cmd = { "wcag-lsp" },
	filetypes = { "html", "javascriptreact", "typescriptreact", "vue", "svelte" },
	root_markers = { ".wcag-lsp.toml", ".git" },
	capabilities = capabilities,
})
vim.lsp.enable("wcag_lsp")

-- ---------------------------------------------------------------------------
-- debugging
-- ---------------------------------------------------------------------------

local dap = require("dap")
local dapui = require("dapui")

local mason_bin = vim.fn.stdpath("data") .. "/mason/bin/"

-- codelldb speaks DAP over a socket, so it is launched as a server and nvim
-- connects to the port it prints on startup
dap.adapters.codelldb = {
	type = "server",
	port = "${port}",
	executable = {
		command = mason_bin .. "codelldb",
		args = { "--port", "${port}" },
	},
}

local function pick_executable()
	return coroutine.create(function(co)
		vim.ui.input({
			prompt = "Path to executable: ",
			default = vim.fn.getcwd() .. "/",
			completion = "file",
		}, function(input)
			coroutine.resume(co, input)
		end)
	end)
end

local native_config = {
	{
		name = "Launch executable",
		type = "codelldb",
		request = "launch",
		program = pick_executable,
		cwd = "${workspaceFolder}",
		stopOnEntry = false,
		args = {},
	},
	{
		name = "Attach to process",
		type = "codelldb",
		request = "attach",
		pid = require("dap.utils").pick_process,
		cwd = "${workspaceFolder}",
	},
}

dap.configurations.c = native_config
dap.configurations.cpp = native_config
dap.configurations.rust = native_config
dap.configurations.odin = native_config

-- delve adapter + the go launch configurations come from nvim-dap-go
require("dap-go").setup({
	delve = { path = mason_bin .. "dlv" },
})

require("nvim-dap-virtual-text").setup({
	virt_text_pos = "eol",
	commented = true,
})

dapui.setup({
	icons = { expanded = "▾", collapsed = "▸", current_frame = "▸" },
	layouts = {
		{
			elements = {
				{ id = "scopes", size = 0.30 },
				{ id = "breakpoints", size = 0.20 },
				{ id = "stacks", size = 0.25 },
				{ id = "watches", size = 0.25 },
			},
			size = 44,
			position = "left",
		},
		{
			elements = {
				{ id = "repl", size = 0.5 },
				{ id = "console", size = 0.5 },
			},
			size = 12,
			position = "bottom",
		},
	},
})

-- open the ui when a session starts, close it when it ends
dap.listeners.after.event_initialized["dapui_config"] = dapui.open
dap.listeners.before.event_terminated["dapui_config"] = dapui.close
dap.listeners.before.event_exited["dapui_config"] = dapui.close

vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "DiagnosticSignError", numhl = "" })
vim.fn.sign_define("DapBreakpointCondition", { text = "◆", texthl = "DiagnosticSignWarn", numhl = "" })
vim.fn.sign_define("DapLogPoint", { text = "◉", texthl = "DiagnosticSignInfo", numhl = "" })
vim.fn.sign_define("DapStopped", { text = "▶", texthl = "DiagnosticSignWarn", linehl = "Visual", numhl = "" })

-- function keys for step control (layout independent), <leader>b for breakpoints
set("n", "<F5>", dap.continue, { desc = "Debug: start / continue" })
set("n", "<F9>", dap.toggle_breakpoint, { desc = "Debug: toggle breakpoint" })
set("n", "<F10>", dap.step_over, { desc = "Debug: step over" })
set("n", "<F11>", dap.step_into, { desc = "Debug: step into" })
set("n", "<F12>", dap.step_out, { desc = "Debug: step out" })
set("n", "<leader>b", dap.toggle_breakpoint, { desc = "Debug: toggle [B]reakpoint" })
set("n", "<leader>B", function()
	vim.ui.input({ prompt = "Breakpoint condition: " }, function(cond)
		if cond then
			dap.set_breakpoint(cond)
		end
	end)
end, { desc = "Debug: conditional [B]reakpoint" })
set("n", "<leader>dl", function()
	vim.ui.input({ prompt = "Log point message: " }, function(msg)
		if msg then
			dap.set_breakpoint(nil, nil, msg)
		end
	end)
end, { desc = "Debug: [L]og point" })
set("n", "<leader>du", dapui.toggle, { desc = "Debug: toggle [U]I" })
set("n", "<leader>dt", dap.terminate, { desc = "Debug: [T]erminate session" })
set("n", "<leader>dc", dap.run_to_cursor, { desc = "Debug: run to [C]ursor" })
set("n", "<leader>dR", dap.restart, { desc = "Debug: [R]estart session" })
set("n", "<leader>db", dap.list_breakpoints, { desc = "Debug: list [B]reakpoints in quickfix" })
set({ "n", "v" }, "<leader>dh", function()
	require("dap.ui.widgets").hover()
end, { desc = "Debug: [H]over value" })
