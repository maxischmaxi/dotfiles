require("lazydev").setup({
	library = {
		{ path = "${3rd}/luv/library", words = { "vim%.uv" } },
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
	"prettierd",
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