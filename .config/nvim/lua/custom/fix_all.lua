-- "fix all" entries for the code action menu. for every diagnostic under the
-- cursor whose code occurs more than once in the buffer, <leader>ca gets an
-- extra item that applies the first quickfix of each such diagnostic at once.
-- clangd has no source.fixAll, so the quickfixes are requested for all matching
-- diagnostics and their edits merged into one workspace edit.

local M = {}

local TIMEOUT_MS = 5000

-- diagnostics of one client in one buffer (push and default pull namespace)
local function client_diagnostics(client, bufnr, opts)
	local out = {}
	for _, is_pull in ipairs({ false, true }) do
		local ns = vim.lsp.diagnostic.get_namespace(client.id, is_pull)
		vim.list_extend(out, vim.diagnostic.get(bufnr, vim.tbl_extend("force", opts or {}, { namespace = ns })))
	end
	return out
end

-- same rule nvim uses to pick the diagnostics for a code action request
local function contains_cursor(d, lnum, col)
	local end_lnum, end_col = d.end_lnum or d.lnum, d.end_col or d.col
	if d.lnum == end_lnum and d.col == end_col then
		return lnum == d.lnum and col == d.col
	end
	local after_start = lnum > d.lnum or (lnum == d.lnum and col >= d.col)
	local before_end = lnum < end_lnum or (lnum == end_lnum and col < end_col)
	return after_start and before_end
end

local function candidates(bufnr, lnum, col)
	local out, seen = {}, {}
	for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr, method = "textDocument/codeAction" })) do
		for _, d in ipairs(client_diagnostics(client, bufnr, { lnum = lnum })) do
			local key = client.id .. ":" .. tostring(d.code)
			if d.code ~= nil and not seen[key] and contains_cursor(d, lnum, col) then
				seen[key] = true
				local same = vim.tbl_filter(function(o)
					return o.code == d.code
				end, client_diagnostics(client, bufnr))
				if #same > 1 then
					out[#out + 1] = {
						client_id = client.id,
						bufnr = bufnr,
						code = d.code,
						title = ("Fix all: %s (%d in buffer)"):format(d.code, #same),
					}
				end
			end
		end
	end
	return out
end

local function is_quickfix(action)
	-- a bare Command has no edit to merge
	if type(action.command) == "string" or action.disabled then
		return false
	end
	return action.kind == nil or vim.startswith(action.kind, "quickfix")
end

-- identifies the diagnostic a quickfix belongs to, nil if the server did not say
local function diagnostic_key(action)
	local d = action.diagnostics and action.diagnostics[1]
	if not d then
		return nil
	end
	local r = d.range
	return ("%d:%d-%d:%d %s"):format(r.start.line, r.start.character, r["end"].line, r["end"].character, d.message)
end

local function collect_edits(edit, into)
	for uri, edits in pairs(edit.changes or {}) do
		into[uri] = into[uri] or {}
		vim.list_extend(into[uri], edits)
	end
	for _, change in ipairs(edit.documentChanges or {}) do
		-- create/rename/delete file operations are not batched
		if change.textDocument then
			local uri = change.textDocument.uri
			into[uri] = into[uri] or {}
			vim.list_extend(into[uri], change.edits)
		end
	end
end

local function pos_lt(a, b)
	return a.line < b.line or (a.line == b.line and a.character < b.character)
end

-- drops duplicate edits and edits overlapping an earlier one
local function sanitize(edits)
	table.sort(edits, function(a, b)
		return pos_lt(a.range.start, b.range.start)
	end)
	local out, seen, last_end = {}, {}, nil
	for _, e in ipairs(edits) do
		local r = e.range
		local key = ("%d:%d-%d:%d|%s"):format(
			r.start.line,
			r.start.character,
			r["end"].line,
			r["end"].character,
			e.newText
		)
		if not seen[key] and not (last_end and pos_lt(r.start, last_end)) then
			seen[key] = true
			out[#out + 1] = e
			last_end = r["end"]
		end
	end
	return out, #edits - #out
end

---@param cand { client_id: integer, bufnr: integer, code: string|integer }
function M.fix_all(cand)
	local client = vim.lsp.get_client_by_id(cand.client_id)
	local bufnr = cand.bufnr
	if not client or not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end

	local diags = vim.tbl_filter(function(d)
		return d.code == cand.code and d.user_data and d.user_data.lsp
	end, client_diagnostics(client, bufnr))
	if #diags == 0 then
		vim.notify(("fix all: no diagnostics left for %s"):format(cand.code), vim.log.levels.INFO)
		return
	end

	local last = vim.api.nvim_buf_line_count(bufnr) - 1
	local last_line = vim.api.nvim_buf_get_lines(bufnr, last, last + 1, true)[1]
	local params = {
		textDocument = vim.lsp.util.make_text_document_params(bufnr),
		range = {
			start = { line = 0, character = 0 },
			["end"] = { line = last, character = vim.str_utfindex(last_line, client.offset_encoding) },
		},
		context = {
			only = { "quickfix" },
			triggerKind = vim.lsp.protocol.CodeActionTriggerKind.Invoked,
			diagnostics = vim.tbl_map(function(d)
				return d.user_data.lsp
			end, diags),
		},
	}

	-- sync on purpose: the buffer must not change between request and apply
	local res, err = client:request_sync("textDocument/codeAction", params, TIMEOUT_MS, bufnr)
	if not res or res.err or not res.result then
		local msg = err or (res and res.err and res.err.message) or "no result"
		vim.notify("fix all: codeAction request failed: " .. tostring(msg), vim.log.levels.ERROR)
		return
	end

	local changes, seen_diag, applied, skipped = {}, {}, 0, 0
	for _, action in ipairs(res.result) do
		if is_quickfix(action) then
			local key = diagnostic_key(action)
			-- a diagnostic with several alternative fixes only gets the first one
			if not key or not seen_diag[key] then
				if key then
					seen_diag[key] = true
				end
				if not action.edit and client:supports_method("codeAction/resolve") then
					local r = client:request_sync("codeAction/resolve", action, TIMEOUT_MS, bufnr)
					action = r and r.result or action
				end
				if action.edit then
					collect_edits(action.edit, changes)
					applied = applied + 1
				else
					skipped = skipped + 1
				end
			end
		end
	end

	local dropped = 0
	for uri, edits in pairs(changes) do
		local clean, n = sanitize(edits)
		changes[uri] = clean
		dropped = dropped + n
	end

	if applied > 0 then
		vim.lsp.util.apply_workspace_edit({ changes = changes }, client.offset_encoding)
	end

	local msg = ("fix all: %d of %d %s fixed"):format(applied, #diags, cand.code)
	if skipped > 0 then
		msg = msg .. (", %d skipped (command only)"):format(skipped)
	end
	if dropped > 0 then
		msg = msg .. (", %d overlapping edits dropped"):format(dropped)
	end
	vim.notify(msg, vim.log.levels.INFO)
end

local pending, wrapped

local function wrap_select(orig)
	return function(items, opts, on_choice)
		local cands = pending
		if not cands or not opts or opts.kind ~= "codeaction" or not (items[1] and items[1].ctx) then
			return orig(items, opts, on_choice)
		end
		pending = nil

		local extended = vim.list_extend({}, items)
		for _, c in ipairs(cands) do
			-- shaped like nvim's own items so its format_item works on them
			extended[#extended + 1] = {
				action = { title = c.title },
				ctx = { bufnr = c.bufnr, client_id = c.client_id },
				fix_all = c,
			}
		end

		return orig(extended, opts, function(choice, idx)
			if choice and choice.fix_all then
				return M.fix_all(choice.fix_all)
			end
			return on_choice(choice, idx)
		end)
	end
end

-- vim.lsp.buf.code_action with the fix-all items appended to its menu
function M.code_action()
	pending = nil
	if vim.api.nvim_get_mode().mode == "n" then
		local bufnr = vim.api.nvim_get_current_buf()
		local cursor = vim.api.nvim_win_get_cursor(0)
		local cands = candidates(bufnr, cursor[1] - 1, cursor[2])
		if #cands > 0 then
			pending = cands
			-- telescope-ui-select swaps vim.ui.select at runtime, so wrap
			-- whatever is current now instead of once at startup
			if vim.ui.select ~= wrapped then
				wrapped = wrap_select(vim.ui.select)
				vim.ui.select = wrapped
			end
		end
	end
	vim.lsp.buf.code_action()
end

return M
