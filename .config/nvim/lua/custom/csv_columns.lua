local M = {}

local ns = vim.api.nvim_create_namespace("csv_columns")

-- one fg color per column, cycled; picked from the tokyonight palette and
-- ordered so neighbouring columns stay far apart in hue
local default_colors = {
	"#7aa2f7",
	"#e0af68",
	"#9ece6a",
	"#bb9af7",
	"#f7768e",
	"#7dcfff",
	"#ff9e64",
	"#73daca",
}

-- tried in this order, so a tie falls back to the more common delimiter
local candidates = { ",", ";", "\t", "|" }

local config = {
	filetypes = { "csv", "tsv" },
	colors = default_colors,
	-- render the first line bold in its column color
	header = true,
	-- lines sampled when guessing the delimiter
	sample_lines = 50,
	-- guards: a runaway line or column count must not stall a redraw
	max_line_length = 8192,
	max_columns = 128,
}

-- buffers we paint, keyed by bufnr: { delim = "," }
local active = {}

-- Byte ranges of every field in a line, 0-based and end-exclusive, delimiters
-- excluded. A field that opens with a quote keeps its delimiters ("a,b" is one
-- field) until the closing quote; a doubled quote inside is an escaped one.
-- Records spanning multiple lines are not tracked - each line stands alone.
local function split(line, delim)
	local fields = {}
	local len = #line
	local delim_byte = delim:byte()
	local start, i = 1, 1
	local quoted, leading = false, true

	while i <= len do
		local b = line:byte(i)
		if quoted then
			if b == 34 then
				if line:byte(i + 1) == 34 then
					i = i + 1
				else
					quoted = false
				end
			end
		elseif b == delim_byte then
			fields[#fields + 1] = { start - 1, i - 1 }
			if #fields >= config.max_columns then
				return fields
			end
			start, leading = i + 1, true
		elseif b == 34 and leading then
			quoted, leading = true, false
		elseif b ~= 32 and b ~= 9 then
			leading = false
		end
		i = i + 1
	end

	fields[#fields + 1] = { start - 1, len }
	return fields
end

-- The field count a delimiter produces most often, plus the share of lines
-- agreeing with it. A count of 1 means the delimiter never appeared outside
-- quotes, so it does not count as evidence.
local function score(lines, delim)
	local counts = {}
	for _, line in ipairs(lines) do
		local n = #split(line, delim)
		counts[n] = (counts[n] or 0) + 1
	end

	local cols, hits = 0, 0
	for n, seen in pairs(counts) do
		if n > 1 and (seen > hits or (seen == hits and n > cols)) then
			cols, hits = n, seen
		end
	end
	return cols, hits / #lines
end

local function detect(bufnr)
	if vim.bo[bufnr].filetype == "tsv" then
		return "\t"
	end

	local lines = {}
	for _, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, config.sample_lines, false)) do
		if line ~= "" and #line <= config.max_line_length then
			lines[#lines + 1] = line
		end
	end
	if #lines == 0 then
		return ","
	end

	-- best agreement wins; on a tie the delimiter splitting into more columns
	-- does, which is what separates "a;b;c" (semicolon) from a stray comma
	local best, best_cols, best_ratio = nil, 0, 0
	for _, delim in ipairs(candidates) do
		local cols, ratio = score(lines, delim)
		if cols > 1 and (ratio > best_ratio or (ratio == best_ratio and cols > best_cols)) then
			best, best_cols, best_ratio = delim, cols, ratio
		end
	end
	return best or ","
end

local function paint(bufnr, row, line, delim, header)
	local fields = split(line, delim)
	local palette = #config.colors
	local prefix = header and "CsvHeader" or "CsvColumn"

	for i, field in ipairs(fields) do
		local from, to = field[1], field[2]
		if to > from then
			vim.api.nvim_buf_set_extmark(bufnr, ns, row, from, {
				end_row = row,
				end_col = to,
				hl_group = prefix .. ((i - 1) % palette + 1),
				priority = 120,
				ephemeral = true,
			})
		end
		if i < #fields then
			vim.api.nvim_buf_set_extmark(bufnr, ns, row, to, {
				end_row = row,
				end_col = to + #delim,
				hl_group = "CsvDelimiter",
				priority = 120,
				ephemeral = true,
			})
		end
	end
end

vim.api.nvim_set_decoration_provider(ns, {
	on_win = function(_, _, bufnr)
		return active[bufnr] ~= nil
	end,
	on_line = function(_, _, bufnr, row)
		local state = active[bufnr]
		if not state then
			return
		end
		local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
		if not line or line == "" or #line > config.max_line_length then
			return
		end
		paint(bufnr, row, line, state.delim, config.header and row == 0)
	end,
})

-- A decoration provider only runs for lines nvim already considers dirty, and
-- attaching a buffer dirties nothing, so the window has to be invalidated.
local function redraw(bufnr)
	if not pcall(vim.api.nvim__redraw, { buf = bufnr, valid = false, flush = true }) then
		pcall(vim.cmd, "redraw!")
	end
end

local function set_highlights()
	for i, color in ipairs(config.colors) do
		vim.api.nvim_set_hl(0, "CsvColumn" .. i, { fg = color })
		vim.api.nvim_set_hl(0, "CsvHeader" .. i, { fg = color, bold = true })
	end
	vim.api.nvim_set_hl(0, "CsvDelimiter", { link = "Comment" })
end

local function attach(bufnr, delim)
	active[bufnr] = { delim = delim or detect(bufnr) }
	redraw(bufnr)
end

local function detach(bufnr)
	active[bufnr] = nil
	redraw(bufnr)
end

-- printable form of a delimiter, so a tab does not show up as nothing
local function label(delim)
	return delim == "\t" and "<Tab>" or delim
end

function M.toggle(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	if active[bufnr] then
		detach(bufnr)
		vim.notify("CSV columns off", vim.log.levels.INFO)
	else
		attach(bufnr)
		vim.notify("CSV columns on, delimiter " .. label(active[bufnr].delim), vim.log.levels.INFO)
	end
end

-- with no delimiter: report the current one. With one: use it from now on,
-- turning the highlighting on if the buffer was not painted yet
function M.delimiter(delim, bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()

	if not delim or delim == "" then
		local state = active[bufnr]
		vim.notify(state and ("CSV delimiter " .. label(state.delim)) or "CSV columns off", vim.log.levels.INFO)
		return
	end

	if delim == "\\t" or delim == "tab" then
		delim = "\t"
	end
	if #delim ~= 1 then
		vim.notify("CSV delimiter must be a single character", vim.log.levels.ERROR)
		return
	end

	attach(bufnr, delim)
	vim.notify("CSV delimiter " .. label(delim), vim.log.levels.INFO)
end

function M.setup(opts)
	-- flat merge on purpose: a user list replaces the default instead of being
	-- padded with leftover defaults
	config = vim.tbl_extend("force", config, opts or {})
	set_highlights()

	local group = vim.api.nvim_create_augroup("CsvColumns", { clear = true })

	vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = set_highlights })

	vim.api.nvim_create_autocmd("FileType", {
		group = group,
		pattern = config.filetypes,
		callback = function(ev)
			attach(ev.buf)
		end,
	})

	vim.api.nvim_create_autocmd({ "BufWipeout", "BufDelete" }, {
		group = group,
		callback = function(ev)
			active[ev.buf] = nil
		end,
	})

	-- buffers already open when this module is loaded (e.g. after :source)
	local wanted = {}
	for _, ft in ipairs(config.filetypes) do
		wanted[ft] = true
	end
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(bufnr) and wanted[vim.bo[bufnr].filetype] then
			attach(bufnr)
		end
	end

	vim.api.nvim_create_user_command("CsvColumns", function()
		M.toggle()
	end, { desc = "Toggle CSV column colors in the current buffer" })

	vim.api.nvim_create_user_command("CsvDelimiter", function(info)
		M.delimiter(info.args)
	end, { nargs = "?", desc = "Show or set the CSV delimiter for the current buffer" })
end

return M
