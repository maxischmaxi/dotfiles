local M = {}

local ns = vim.api.nvim_create_namespace("char_jump")

-- fwd = search direction, till = stop one character short (t/T)
local motions = {
	f = { fwd = true, till = false },
	F = { fwd = false, till = false },
	t = { fwd = true, till = true },
	T = { fwd = false, till = true },
}

local mapped_keys = { "f", "F", "t", "T", ";", "," }

-- search currently painted on screen: { win, buf, rows, cur_row, cur_col, len }
M.state = nil
-- last search, so a cold ; or , can repeat it: { char, key }
M.last = nil

vim.api.nvim_set_decoration_provider(ns, {
	on_win = function(_, winid, bufnr)
		local s = M.state
		return s ~= nil and winid == s.win and bufnr == s.buf
	end,
	on_line = function(_, _, bufnr, row)
		local s = M.state
		if not s then
			return
		end
		local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
		if not line then
			return
		end
		vim.api.nvim_buf_set_extmark(bufnr, ns, row, 0, {
			end_row = row,
			end_col = #line,
			hl_group = "CharJumpBackdrop",
			hl_eol = true,
			priority = 4000,
			ephemeral = true,
		})
		for _, col in ipairs(s.rows and s.rows[row] or {}) do
			local current = row == s.cur_row and col == s.cur_col
			vim.api.nvim_buf_set_extmark(bufnr, ns, row, col, {
				end_row = row,
				end_col = col + s.len,
				hl_group = current and "CharJumpCurrent" or "CharJumpMatch",
				priority = current and 4200 or 4100,
				ephemeral = true,
			})
		end
	end,
})

-- A decoration provider only runs for lines nvim already considers dirty, and
-- flipping M.state dirties nothing at all, so a plain :redraw would paint
-- nothing. The window has to be marked invalid explicitly.
local function redraw(win)
	if win and not vim.api.nvim_win_is_valid(win) then
		win = nil
	end
	if not pcall(vim.api.nvim__redraw, { win = win or 0, valid = false, flush = true }) then
		pcall(vim.cmd, "redraw!")
	end
end

local function backdrop()
	M.state = {
		win = vim.api.nvim_get_current_win(),
		buf = vim.api.nvim_get_current_buf(),
		len = 0,
	}
	redraw(M.state.win)
end

local function clear()
	local win = M.state and M.state.win
	M.state = nil
	redraw(win)
end

-- blocking read of a single printable character; nil on <Esc>, <C-c> or any
-- special key whose internal encoding is not a real character
local function read_char()
	local ok, c = pcall(vim.fn.getcharstr)
	if not ok or c == "" or c == "\27" then
		return nil
	end
	if vim.fn.strchars(c) ~= 1 then
		return nil
	end
	return c
end

-- all matches in the visible part of the current window, sorted by position
local function collect(char)
	local top = vim.fn.line("w0")
	local bot = vim.fn.line("w$")
	local lines = vim.api.nvim_buf_get_lines(0, top - 1, bot, false)
	local list, rows = {}, {}
	for i, line in ipairs(lines) do
		local row = top - 2 + i
		local at = 1
		while true do
			local found = string.find(line, char, at, true)
			if not found then
				break
			end
			local col = found - 1
			rows[row] = rows[row] or {}
			table.insert(rows[row], col)
			table.insert(list, { row = row, col = col })
			at = found + #char
		end
	end
	return list, rows
end

local function before(r1, c1, r2, c2)
	return r1 < r2 or (r1 == r2 and c1 < c2)
end

local function pick(list, row, col, fwd, count)
	local seen = 0
	if fwd then
		for i = 1, #list do
			local m = list[i]
			if before(row, col, m.row, m.col) then
				seen = seen + 1
				if seen == count then
					return m
				end
			end
		end
	else
		for i = #list, 1, -1 do
			local m = list[i]
			if before(m.row, m.col, row, col) then
				seen = seen + 1
				if seen == count then
					return m
				end
			end
		end
	end
end

-- start of the character preceding byte column col
local function prev_col(line, col)
	if col <= 0 then
		return 0
	end
	return (col - 1) + vim.str_utf_start(line, col)
end

-- Where the cursor has to land. A cursor move out of a mapping is an exclusive
-- motion, so under an operator f needs one character extra to cover the match
-- and t stops right on it ("exclusive"). A forced charwise motion (dvfx) flips
-- that back to inclusive, so the target moves one character earlier
-- ("inclusive"). Everything else lands straight on the match ("plain").
local function target_col(match, char, fwd, till, variant)
	local line = vim.api.nvim_buf_get_lines(0, match.row, match.row + 1, false)[1] or ""
	local col
	if not fwd then
		col = till and match.col + #char or match.col
	elseif variant == "exclusive" then
		col = till and match.col or match.col + #char
	elseif variant == "inclusive" then
		col = prev_col(line, match.col)
		if till then
			col = prev_col(line, col)
		end
	else
		col = till and prev_col(line, match.col) or match.col
	end

	local limit = variant == "exclusive" and #line or prev_col(line, #line)
	if col > limit then
		col = limit
	end
	return col
end

-- count-th match in the given direction, or nil
local function find(char, fwd, till, count, skip)
	local cursor = vim.api.nvim_win_get_cursor(0)
	local row, col = cursor[1] - 1, cursor[2]

	-- t/T park us next to the match, so a repeat would find it again
	if skip and till then
		col = fwd and col + 1 or col - 1
	end

	return pick(collect(char), row, col, fwd, count)
end

local function jump_to(match, char, fwd, till, variant)
	local win = vim.api.nvim_get_current_win()
	local col = target_col(match, char, fwd, till, variant)
	local line = vim.api.nvim_buf_get_lines(0, match.row, match.row + 1, false)[1] or ""

	if col >= #line and #line > 0 then
		-- an exclusive motion has to be able to land one past the last character
		local saved = vim.wo[win].virtualedit
		vim.wo[win].virtualedit = "onemore"
		vim.schedule(function()
			if vim.api.nvim_win_is_valid(win) then
				vim.wo[win].virtualedit = saved
			end
		end)
	end

	vim.api.nvim_win_set_cursor(win, { match.row + 1, col })
	-- keep native ; and , in sync for everything still running unmapped
	vim.fn.setcharsearch({ char = char, forward = fwd and 1 or 0, ["until"] = till and 1 or 0 })
end

-- recollect for the (possibly scrolled) new viewport and repaint
local function paint(char, match)
	local _, rows = collect(char)
	M.state = {
		win = vim.api.nvim_get_current_win(),
		buf = vim.api.nvim_get_current_buf(),
		rows = rows,
		cur_row = match.row,
		cur_col = match.col,
		len = #char,
	}
	redraw(M.state.win)
end

-- resolve which search a key starts: f/F/t/T carry their own, ; and , reuse the
-- last one, with , flipping the direction
local function resolve(key)
	local fresh = motions[key] ~= nil
	local base = fresh and key or (M.last and M.last.key)
	if not base then
		return nil
	end
	local spec = motions[base]
	local fwd = spec.fwd
	if key == "," then
		fwd = not fwd
	end
	return { fresh = fresh, base = base, till = spec.till, fwd = fwd }
end

-- stay resident after the first jump: the initiating motion's own key and ;
-- continue in its direction, the opposite-case key and , go back
local function loop(base, char, spec)
	local next_keys = { [";"] = true, [base:lower()] = true }
	local prev_keys = { [","] = true, [base:upper()] = true }

	while true do
		local ok, key = pcall(vim.fn.getcharstr)
		if not ok or key == "" then
			break
		end

		local fwd
		if next_keys[key] then
			fwd = spec.fwd
		elseif prev_keys[key] then
			fwd = not spec.fwd
		else
			clear()
			-- "i" puts the key back at the front of the typeahead. Without it the
			-- key is appended behind whatever the user already typed ahead, which
			-- reorders fast input like fs followed by ifoo<Esc>.
			vim.api.nvim_feedkeys(key, "mi", false)
			return
		end

		local match = find(char, fwd, spec.till, 1, true)
		if match then
			jump_to(match, char, fwd, spec.till, "plain")
			paint(char, match)
		else
			redraw()
		end
	end
	clear()
end

local function run(key)
	local spec = resolve(key)
	if not spec then
		return
	end

	local char
	if spec.fresh then
		backdrop()
		char = read_char()
		if not char then
			return clear()
		end
		M.last = { char = char, key = key }
	else
		char = M.last.char
	end

	local match = find(char, spec.fwd, spec.till, vim.v.count1, not spec.fresh)
	if not match then
		return clear()
	end

	jump_to(match, char, spec.fwd, spec.till, "plain")
	paint(char, match)
	loop(spec.base, char, motions[spec.base])
end

function M.motion(key)
	local ok, err = pcall(run, key)
	if not ok then
		clear()
		vim.notify("char_jump: " .. tostring(err), vim.log.levels.ERROR)
	end
end

-- encode a byte string so it survives being embedded in a <Cmd> lua literal
local function encode(s)
	return (s:gsub(".", function(b)
		return string.format("\\%03d", b:byte())
	end))
end

-- Operator-pending needs an <expr> mapping: only keys returned from one end up
-- in the redo buffer, which is what makes dot-repeat work. redraw and
-- getcharstr are both allowed here, so the backdrop still shows while we wait
-- for the character. The character is baked into the returned command so a
-- later . replays the search instead of prompting again.
local function op_expr(key)
	local spec = resolve(key)
	if not spec then
		return ""
	end

	local char
	if spec.fresh then
		backdrop()
		char = read_char()
		clear()
		if not char then
			return ""
		end
		M.last = { char = char, key = key }
	else
		char = M.last.char
	end

	return string.format(
		"<Cmd>lua require('custom.char_jump').op_motion('%s', %s, %s, %d, %s)<CR>",
		encode(char),
		tostring(spec.fwd),
		tostring(spec.till),
		vim.v.count1,
		tostring(not spec.fresh)
	)
end

function M.op_motion(char, fwd, till, count, skip)
	local mode = vim.fn.mode(true)
	local variant = "plain"
	if mode:sub(1, 2) == "no" then
		local force = mode:sub(3)
		if force == "" then
			variant = "exclusive"
		elseif force == "v" then
			variant = "inclusive"
		end
	end

	local match = find(char, fwd, till, count, skip)
	if match then
		jump_to(match, char, fwd, till, variant)
	end
end

local function set_highlights()
	vim.api.nvim_set_hl(0, "CharJumpBackdrop", { link = "Comment" })
	vim.api.nvim_set_hl(0, "CharJumpMatch", { fg = "#c0caf5", bg = "#3d59a1", bold = true })
	vim.api.nvim_set_hl(0, "CharJumpCurrent", { fg = "#1a1b26", bg = "#ff9e64", bold = true })
end

function M.setup()
	set_highlights()

	vim.api.nvim_create_autocmd("ColorScheme", {
		group = vim.api.nvim_create_augroup("CharJump", { clear = true }),
		callback = set_highlights,
	})

	for _, key in ipairs(mapped_keys) do
		vim.keymap.set({ "n", "x" }, key, function()
			M.motion(key)
		end, { desc = "Char jump " .. key })

		vim.keymap.set("o", key, function()
			local ok, result = pcall(op_expr, key)
			if not ok then
				clear()
				vim.schedule(function()
					vim.notify("char_jump: " .. tostring(result), vim.log.levels.ERROR)
				end)
				return ""
			end
			return result
		end, { expr = true, desc = "Char jump " .. key })
	end
end

return M
