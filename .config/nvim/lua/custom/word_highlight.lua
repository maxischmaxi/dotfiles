-- Toggleable highlight of every occurrence of the word under the cursor.
-- Uses matchadd(): a native regex per window, no Lua scan of the buffer and
-- no deprecated nvim_buf_add_highlight.
local M = {}

M.enabled = false

-- match id per window, so the highlight is removed where it was added
local matches = {}

local group = vim.api.nvim_create_augroup("WordHighlight", { clear = true })

local function clear()
	for win, id in pairs(matches) do
		if vim.api.nvim_win_is_valid(win) then
			pcall(vim.fn.matchdelete, id, win)
		end
		matches[win] = nil
	end
end

local function highlight()
	clear()
	local word = vim.fn.expand("<cword>")
	if word == "" then
		return
	end
	-- \V: no magic, \< \>: keyword boundaries, the same rule <cword> follows
	local pattern = [[\V\<]] .. vim.fn.escape(word, [[\]]) .. [[\>]]
	local win = vim.api.nvim_get_current_win()
	matches[win] = vim.fn.matchadd("WordHighlight", pattern, 10, -1, { window = win })
end

function M.toggle()
	M.enabled = not M.enabled
	vim.api.nvim_clear_autocmds({ group = group })

	if M.enabled then
		vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, { group = group, callback = highlight })
		vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, { group = group, callback = clear })
		highlight()
	else
		clear()
	end
	vim.notify("Word highlighting " .. (M.enabled and "enabled" or "disabled"), vim.log.levels.INFO)
end

local function set_highlights()
	-- tokyonight blue, close to its search highlight
	vim.api.nvim_set_hl(0, "WordHighlight", { bg = "#3d59a1", bold = true })
end

function M.setup()
	set_highlights()
	vim.api.nvim_create_autocmd("ColorScheme", {
		group = vim.api.nvim_create_augroup("WordHighlightColors", { clear = true }),
		callback = set_highlights,
	})
end

return M
