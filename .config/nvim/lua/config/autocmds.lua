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

vim.api.nvim_create_autocmd("LspAttach", {
	group = vim.api.nvim_create_augroup("custom-lsp-codelens", { clear = true }),
	callback = function(ev)
		local client = vim.lsp.get_client_by_id(ev.data.client_id)
		if client and client:supports_method("textDocument/codeLens", ev.buf) then
			vim.lsp.codelens.enable(true, { bufnr = ev.buf })
			vim.keymap.set("n", "<leader>cl", vim.lsp.codelens.run, { buffer = ev.buf, desc = "Run code lens" })
		end
	end,
})

-- cursor-hold reference highlighting, one augroup shared by all buffers
local highlight_augroup = vim.api.nvim_create_augroup("custom-lsp-highlight", { clear = true })

vim.api.nvim_create_autocmd("LspAttach", {
	group = vim.api.nvim_create_augroup("custom-lsp-attach", { clear = true }),
	callback = function(ev)
		local map = function(keys, func, desc, mode)
			mode = mode or "n"
			vim.keymap.set(mode, keys, func, { buffer = ev.buf, desc = "LSP: " .. desc })
		end

		local client = vim.lsp.get_client_by_id(ev.data.client_id)
		if not client then
			return
		end

		if client:supports_method(vim.lsp.protocol.Methods.textDocument_documentHighlight, ev.buf) then
			-- a second capable client on the same buffer must not double the requests
			vim.api.nvim_clear_autocmds({ group = highlight_augroup, buffer = ev.buf })

			vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
				buffer = ev.buf,
				group = highlight_augroup,
				callback = vim.lsp.buf.document_highlight,
			})

			vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
				buffer = ev.buf,
				group = highlight_augroup,
				callback = vim.lsp.buf.clear_references,
			})
		end

		if client:supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint, ev.buf) then
			map("<leader>th", function()
				vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = ev.buf }))
			end, "[T]oggle Inlay [H]ints")
		end

		if client:supports_method(vim.lsp.protocol.Methods.textDocument_codeAction, ev.buf) then
			map("<leader>ca", vim.lsp.buf.code_action, "[C]ode [A]ctions")
		end
	end,
})

vim.api.nvim_create_autocmd("LspDetach", {
	group = vim.api.nvim_create_augroup("custom-lsp-detach", { clear = true }),
	callback = function(ev)
		vim.lsp.buf.clear_references()
		vim.api.nvim_clear_autocmds({ group = highlight_augroup, buffer = ev.buf })
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
