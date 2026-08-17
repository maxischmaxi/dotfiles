local M = {}

M.enabled = false
M.namespace = vim.api.nvim_create_namespace("word_highlight")

-- Function to get word under cursor
local function get_word_under_cursor()
	local word = vim.fn.expand("<cword>")
	if word == "" or word:match("^%s*$") then
		return nil
	end
	return word
end

-- Function to highlight all occurrences of a word in the current buffer
local function highlight_word(word)
	local bufnr = vim.api.nvim_get_current_buf()
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

	-- Clear previous highlights
	vim.api.nvim_buf_clear_namespace(bufnr, M.namespace, 0, -1)

	-- Escape special characters for Lua pattern matching
	local escaped_word = vim.pesc(word)
	-- Match whole words only using Lua patterns
	-- %f[%w] is a frontier pattern that matches word boundaries
	local pattern = "%f[%w_]" .. escaped_word .. "%f[^%w_]"

	-- Highlight all occurrences
	for line_num, line_text in ipairs(lines) do
		local col = 1
		while col <= #line_text do
			local start_col, end_col = line_text:find(pattern, col)
			if not start_col then
				break
			end

			-- Add highlight (API uses 0-based indexing)
			vim.api.nvim_buf_add_highlight(
				bufnr,
				M.namespace,
				"WordHighlight",
				line_num - 1,
				start_col - 1,
				end_col
			)

			col = end_col + 1
		end
	end
end

-- Function to clear all highlights
local function clear_highlights()
	local bufnr = vim.api.nvim_get_current_buf()
	vim.api.nvim_buf_clear_namespace(bufnr, M.namespace, 0, -1)
end

-- Toggle function
function M.toggle()
	M.enabled = not M.enabled

	if M.enabled then
		-- Setup autocommands for automatic highlighting
		local group = vim.api.nvim_create_augroup("WordHighlight", { clear = true })

		vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
			group = group,
			callback = function()
				if M.enabled then
					local word = get_word_under_cursor()
					if word then
						highlight_word(word)
					else
						clear_highlights()
					end
				end
			end,
		})

		vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
			group = group,
			callback = function()
				if M.enabled then
					clear_highlights()
				end
			end,
		})

		-- Highlight immediately if on a word
		local word = get_word_under_cursor()
		if word then
			highlight_word(word)
		end

		print("Word highlighting enabled")
	else
		-- Clear autocommands and highlights
		vim.api.nvim_clear_autocmds({ group = "WordHighlight" })
		clear_highlights()
		print("Word highlighting disabled")
	end
end

-- Setup highlight group using TokyoNight theme colors
function M.setup()
	-- Use a color from TokyoNight theme - yellow with some transparency
	-- This color is similar to the search highlight in TokyoNight
	vim.api.nvim_set_hl(0, "WordHighlight", {
		bg = "#3d59a1", -- TokyoNight blue background
		bold = true,
	})
end

return M
