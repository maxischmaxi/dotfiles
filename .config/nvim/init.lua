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
vim.g.mapleader = " "
vim.o.signcolumn = "yes"
vim.g.loaded_perl_provider = 0
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
	"https://github.com/BurntSushi/ripgrep",
	"https://github.com/nvim-telescope/telescope-fzf-native.nvim",
	"https://github.com/nvim-telescope/telescope-ui-select.nvim",
	"https://github.com/nvim-treesitter/nvim-treesitter",
	"https://github.com/nvim-treesitter/nvim-treesitter-textobjects",
	"https://github.com/windwp/nvim-ts-autotag",
	"https://github.com/kylechui/nvim-surround",
	"https://github.com/rhysd/conflict-marker.vim",
	"https://github.com/windwp/nvim-autopairs",
	"https://github.com/nvim-pack/nvim-spectre",
	"https://github.com/stevearc/conform.nvim",
	"https://github.com/folke/tokyonight.nvim",
	"https://github.com/neovim/nvim-lspconfig",
	"https://github.com/mason-org/mason.nvim",
	"https://github.com/WhoIsSethDaniel/mason-tool-installer.nvim",
	"https://github.com/rafamadriz/friendly-snippets",
	"https://github.com/folke/lazydev.nvim",
	{ src = "https://github.com/saghen/blink.cmp", version = "v1.7.0" },
	"https://github.com/nvim-tree/nvim-web-devicons",
	"https://github.com/nvim-lualine/lualine.nvim",
	"https://github.com/lewis6991/gitsigns.nvim",
	"https://github.com/Wansmer/treesj",
	"https://github.com/tpope/vim-fugitive",
	"https://github.com/mg979/vim-visual-multi",
	"https://github.com/derektata/lorem.nvim",
	"https://github.com/maxischmaxi/inc-select.nvim",
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
	callback = function(ev)
		local client = vim.lsp.get_client_by_id(ev.data.client_id)
		if client:supports_method("textDocument/documentColor", ev.buf) then
			vim.lsp.document_color.enable(true, { bufnr = ev.buf })
		end
	end,
})

vim.api.nvim_create_autocmd("LspNotify", {
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

set("n", "<leader>m", require("treesj").toggle, { desc = "[M]erge or [S]plit code block" })
set("n", "<leader>M", function()
	require("treesj").toggle({ split = { recursive = true } })
end, { desc = "[M]erge or [S]plit code block (force split)" })

require("lorem").opts({
	sentence_length = "mixed", -- using a default configuration
	comma_chance = 0.3, -- 30% chance to insert a comma
	max_commas = 2, -- maximum 2 commas per sentence
	debounce_ms = 200, -- default debounce time in milliseconds
})
require("gitsigns").setup()

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

require("spectre").setup({
	replace_engine = {
		["sed"] = {
			cmd = "sed",
			args = vim.fn.has("mac") == 1 and { "-i", "", "-E" } or { "-i", "-E" },
		},
	},
})

set("n", "<leader>sw", function()
	require("spectre").toggle()
end, { desc = "Spectre" })

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
		["_"] = { "trim_whitespace" },
		["*"] = { "codespell" },
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
		local lsp_formatted = { glsl = true, just = true }
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
	desc = "Format eslint on save",
	pattern = { "*.js", "*.ts", "*.jsx", "*.tsx" },
	group = vim.api.nvim_create_augroup("FormatEslint", { clear = true }),
	callback = function(ev)
		vim.lsp.buf.code_action({
			context = { only = { "source.fixAll.eslint" }, diagnostics = {} },
			apply = true,
		})
		vim.wait(100) -- Give LSP time to apply fixes
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
})

vim.api.nvim_create_autocmd("FileType", {
	callback = function(args)
		local lang = vim.treesitter.language.get_lang(vim.bo[args.buf].filetype)
		if lang and vim.treesitter.language.add(lang) then
			vim.treesitter.start(args.buf, lang)
			-- Treesitter-Indent ist fuer Rust fehlerhaft (verschachtelte Struct-Literale
			-- verrutschen) -> dort Neovims eingebauten Indent (runtime/indent/rust.vim) behalten
			if vim.bo[args.buf].filetype ~= "rust" then
				vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
			end
		end
	end,
})

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
		["ui-select"] = {
			require("telescope.themes").get_dropdown(),
		},
	},
})

require("telescope").load_extension("fzf")
require("telescope").load_extension("ui-select")

set("n", "<leader>sf", require("telescope.builtin").find_files, { desc = "[S]earch [F]iles" })
set("n", "<leader>sg", require("telescope.builtin").live_grep, { desc = "[S]earch by [G]rep" })
set("n", "gd", require("telescope.builtin").lsp_definitions, { desc = "[G]oto [D]efinition" })
set("n", "gr", require("telescope.builtin").lsp_references, { desc = "[G]oto [R]eferences" })
set("n", "gI", require("telescope.builtin").lsp_implementations, { desc = "[G]oto [I]mplementation" })
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
	cssmodules_ls = { mason = "cssmodules-language-server" },
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
			},
		},
	},
	jqls = { mason = "jq-lsp" },
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
