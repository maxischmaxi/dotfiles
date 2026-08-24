local util = require("dressing.util")
local M = {}

M.is_supported = function()
	return true
end

local _callback = function(item, idx) end
local _items = {}

local function clear_callback()
	_callback = function() end
	_items = {}
end

local function close_window()
	local callback = _callback
	local items = _items
	clear_callback()
	pcall(vim.api.nvim_win_close, 0, true)
	return callback, items
end

M.choose = function()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local idx = cursor[1]
	local callback, items = close_window()
	callback(items[idx], idx)
end

M.cancel = function()
	local callback = close_window()
	callback(nil, nil)
end

local actions = {
	Close = function()
		M.cancel()
	end,
	Confirm = function()
		M.choose()
	end,
}

local function apply_mappings(bufnr, mappings)
	if not mappings then
		return
	end
	for lhs, rhs in pairs(mappings) do
		local action = type(rhs) == "function" and rhs or actions[rhs]
		if action then
			vim.keymap.set("n", lhs, action, {
				buf = bufnr,
				nowait = true,
				desc = string.format("dressing.select: %s", tostring(rhs)),
			})
		end
	end
end

M.select = function(config, items, opts, on_choice)
	_callback = on_choice
	_items = items

	local bufnr = vim.api.nvim_create_buf(false, true)
	vim.bo[bufnr].swapfile = false
	vim.bo[bufnr].bufhidden = "wipe"
	for k, v in pairs(config.buf_options) do
		vim.bo[bufnr][k] = v
	end

	local lines = {}
	local highlights = {}
	local max_width = opts.prompt and vim.api.nvim_strwidth(opts.prompt) or 1
	for idx, item in ipairs(items) do
		local prefix = ""
		if config.show_numbers then
			prefix = "[" .. idx .. "] "
			table.insert(highlights, { #lines, prefix:len() })
			vim.keymap.set("n", tostring(idx), function()
				local callback, local_items = close_window()
				callback(local_items[idx], idx)
			end, { buf = bufnr, nowait = true, desc = "dressing.select: choose " .. idx })
		end
		local line = prefix .. opts.format_item(item)
		max_width = math.max(max_width, vim.api.nvim_strwidth(line))
		table.insert(lines, line)
	end
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, lines)
	vim.bo[bufnr].modifiable = false

	local ns = vim.api.nvim_create_namespace("DressingSelect")
	for _, hl in ipairs(highlights) do
		local lnum, end_col = unpack(hl)
		vim.api.nvim_buf_set_extmark(bufnr, ns, lnum, 0, {
			end_row = lnum,
			end_col = end_col,
			hl_group = "DressingSelectIdx",
		})
	end

	local width = util.calculate_width(config.relative, max_width, config, 0)
	local height = util.calculate_height(config.relative, #lines, config, 0)
	local winopt = {
		relative = config.relative,
		anchor = "NW",
		row = util.calculate_row(config.relative, height, 0),
		col = util.calculate_col(config.relative, width, 0),
		border = util.resolve_border(config.border),
		width = width,
		height = height,
		zindex = 150,
		style = "minimal",
		title = opts.prompt:gsub("^%s*(.-)%s*$", " %1 "),
		title_pos = config.title_pos or "center",
	}
	winopt = config.override(winopt) or winopt

	local winid = vim.api.nvim_open_win(bufnr, true, winopt)
	for option, value in pairs(config.win_options) do
		vim.api.nvim_set_option_value(option, value, { scope = "local", win = winid })
	end
	vim.bo[bufnr].filetype = "DressingSelect"

	apply_mappings(bufnr, config.mappings)
	vim.api.nvim_create_autocmd("BufLeave", {
		desc = "Cancel vim.ui.select",
		buf = bufnr,
		nested = true,
		once = true,
		callback = M.cancel,
	})
end

return M
