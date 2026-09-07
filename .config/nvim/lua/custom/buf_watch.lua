-- Temporary diagnostics for the "random modified buffer on :qa" problem.
-- Every normal buffer (buftype "") gets an on_lines watcher. A change is
-- logged when the buffer is not shown in any window, when it follows a mouse
-- key, or when an unnamed buffer is changed outside insert mode. on_lines runs
-- synchronously, so the Lua traceback still shows the caller. Remove once the
-- culprit is found.
local M = {}

M.log_path = vim.fs.joinpath(vim.fn.stdpath("state"), "buf_watch.log")

local keys = {}
local KEYS_MAX = 60
local attached = {}
local logged = {}
local LOG_MAX_PER_BUF = 20

vim.on_key(function(key, typed)
	local k = (typed and typed ~= "") and typed or key
	if not k or k == "" then
		return
	end
	keys[#keys + 1] = vim.fn.keytrans(k)
	if #keys > KEYS_MAX then
		table.remove(keys, 1)
	end
end)

local function after_mouse()
	for i = #keys, math.max(1, #keys - 2), -1 do
		if keys[i]:find("Mouse") or keys[i]:find("Drag") or keys[i]:find("Release") then
			return true
		end
	end
	return false
end

local function visible(buf)
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		if vim.api.nvim_win_get_buf(win) == buf then
			return true
		end
	end
	return false
end

local function snapshot(buf, reason, first, new_last)
	local ok_mouse, mouse = pcall(vim.fn.getmousepos)
	local out = {
		string.format("%s  %s", os.date("%Y-%m-%d %H:%M:%S"), reason),
		string.format(
			"buf=%d name=%q ft=%q listed=%s visible=%s curbuf=%d curwin=%d mode=%s",
			buf,
			vim.api.nvim_buf_get_name(buf),
			vim.bo[buf].filetype,
			tostring(vim.bo[buf].buflisted),
			tostring(visible(buf)),
			vim.api.nvim_get_current_buf(),
			vim.api.nvim_get_current_win(),
			vim.fn.mode(1)
		),
		"mouse: " .. (ok_mouse and vim.inspect(mouse, { newline = " ", indent = "" }) or "n/a"),
		"keys: " .. table.concat(keys, " "),
		"vim stack: " .. vim.fn.expand("<stack>"),
		"lua stack:" .. debug.traceback("", 3),
		string.format("changed lines %d-%d:", first + 1, new_last),
	}
	for i, l in ipairs(vim.api.nvim_buf_get_lines(buf, first, math.min(new_last, first + 5), false)) do
		out[#out + 1] = string.format("  %d| %s", first + i, l)
	end
	local fd = io.open(M.log_path, "a")
	if fd then
		fd:write(table.concat(out, "\n"), "\n\n")
		fd:close()
	end
end

local function on_lines(_, buf, _, first, _, new_last)
	if vim.bo[buf].buftype ~= "" then
		return
	end
	local reasons = {}
	if not visible(buf) then
		reasons[#reasons + 1] = "hidden"
	end
	if after_mouse() then
		reasons[#reasons + 1] = "after mouse key"
	end
	if vim.api.nvim_buf_get_name(buf) == "" and not vim.fn.mode():match("^[iR]") then
		reasons[#reasons + 1] = "unnamed, not in insert mode"
	end
	if #reasons == 0 then
		return
	end
	-- formatters and eslint fix hidden buffers on :wa, that is expected
	if vim.fn.expand("<stack>"):find("BufWritePre", 1, true) then
		return
	end

	logged[buf] = (logged[buf] or 0) + 1
	if logged[buf] > LOG_MAX_PER_BUF then
		return
	end
	local reason = table.concat(reasons, ", ")
	snapshot(buf, reason, first, new_last)
	if logged[buf] == 1 then
		vim.schedule(function()
			local name = vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_get_name(buf) or ""
			vim.notify(
				string.format(
					"buf_watch: buffer %d (%s) changed: %s. see :BufWatch",
					buf,
					name == "" and "[No Name]" or vim.fn.fnamemodify(name, ":t"),
					reason
				),
				vim.log.levels.WARN
			)
		end)
	end
end

local function attach(buf)
	if
		attached[buf]
		or not vim.api.nvim_buf_is_valid(buf)
		or not vim.api.nvim_buf_is_loaded(buf)
		or vim.bo[buf].buftype ~= ""
	then
		return
	end
	attached[buf] = vim.api.nvim_buf_attach(buf, false, {
		on_lines = on_lines,
		on_detach = function(_, b)
			attached[b] = nil
		end,
	}) or nil
end

local group = vim.api.nvim_create_augroup("BufWatch", { clear = true })

vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile", "BufEnter", "BufWinEnter" }, {
	group = group,
	callback = function(ev)
		attach(ev.buf)
	end,
})

-- buffers created via nvim_create_buf are not loaded yet when BufNew fires
vim.api.nvim_create_autocmd({ "BufNew", "BufAdd" }, {
	group = group,
	callback = function(ev)
		vim.schedule(function()
			attach(ev.buf)
		end)
	end,
})

-- safety net: a buffer that turned modified without being watched. The event
-- is deferred, so there is no useful stack here, but from now on it is watched.
vim.api.nvim_create_autocmd("OptionSet", {
	group = group,
	pattern = "modified",
	callback = function(ev)
		-- <abuf> is not set for OptionSet, but the event runs with the buffer current
		local buf = ev.buf ~= 0 and ev.buf or vim.api.nvim_get_current_buf()
		if attached[buf] or not vim.api.nvim_buf_is_valid(buf) then
			return
		end
		if not vim.bo[buf].modified or vim.bo[buf].buftype ~= "" then
			return
		end
		local n = vim.api.nvim_buf_line_count(buf)
		snapshot(buf, "turned modified while unwatched", 0, math.min(n, 5))
		attach(buf)
	end,
})

for _, buf in ipairs(vim.api.nvim_list_bufs()) do
	attach(buf)
end

vim.api.nvim_create_user_command("BufWatch", function()
	vim.cmd.tabedit(M.log_path)
end, { desc = "Open the buf_watch log" })

return M
