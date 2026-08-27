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