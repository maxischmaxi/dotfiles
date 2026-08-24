local M = {}

local function is_float(value)
	local _, p = math.modf(value)
	return p ~= 0
end

local function calc_float(value, max_value)
	if value and is_float(value) then
		return math.min(max_value, value * max_value)
	else
		return value
	end
end

-- min_/max_ options accept a list of mixed types, e.g. {20, 0.2} means
-- "20 columns or 20% of the total", picked by the aggregator
local function calc_list(values, max_value, aggregator, limit)
	local ret = limit
	if type(values) == "table" then
		for _, v in ipairs(values) do
			ret = aggregator(ret, calc_float(v, max_value))
		end
		return ret
	else
		ret = aggregator(ret, calc_float(values, max_value))
	end
	return ret
end

local function calculate_dim(desired_size, size, min_size, max_size, total_size)
	local ret = calc_float(size, total_size)
	local min_val = calc_list(min_size, total_size, math.max, 1)
	local max_val = calc_list(max_size, total_size, math.min, total_size)
	if not ret then
		if not desired_size then
			ret = (min_val + max_val) / 2
		else
			ret = calc_float(desired_size, total_size)
		end
	end
	ret = math.min(ret, max_val)
	ret = math.max(ret, min_val)
	return math.floor(ret)
end

local function get_max_width(relative, winid)
	if relative == "editor" then
		return vim.o.columns
	else
		return vim.api.nvim_win_get_width(winid or 0)
	end
end

local function get_max_height(relative, winid)
	if relative == "editor" then
		return vim.o.lines - vim.o.cmdheight
	else
		return vim.api.nvim_win_get_height(winid or 0)
	end
end

M.calculate_col = function(relative, width, winid)
	if relative == "cursor" then
		return 0
	else
		return math.floor((get_max_width(relative, winid) - width) / 2)
	end
end

M.calculate_row = function(relative, height, winid)
	if relative == "cursor" then
		return 0
	else
		return math.floor((get_max_height(relative, winid) - height) / 2)
	end
end

M.calculate_width = function(relative, desired_width, config, winid)
	return calculate_dim(
		desired_width,
		config.width,
		config.min_width,
		config.max_width,
		get_max_width(relative, winid)
	)
end

M.calculate_height = function(relative, desired_height, config, winid)
	return calculate_dim(
		desired_height,
		config.height,
		config.min_height,
		config.max_height,
		get_max_height(relative, winid)
	)
end

---A nil border means "inherit the global 'winborder'". We resolve it instead of
---omitting the key because the layout math needs to know if a border is present.
---@param border? string|string[]
---@return string|string[]
M.resolve_border = function(border)
	border = border or vim.o.winborder
	if border == "" then
		return "none"
	end
	return border
end

M.has_border = function(border)
	return border ~= nil and border ~= "none"
end

---Defer until VimEnter, otherwise opening a window during startup misbehaves
---@param func function
M.schedule_wrap_before_vimenter = function(func)
	return function(...)
		if vim.v.vim_did_enter == 0 then
			return vim.schedule_wrap(func)(...)
		else
			return func(...)
		end
	end
end

---Wrap an async function so that if called multiple times only one will execute concurrently
---@param callback_arg_num integer The position of the callback argument in the function
---@param fn function
M.make_queued_async_fn = function(callback_arg_num, fn)
	local queue = {}
	local consuming = false

	local function consume()
		if #queue == 0 then
			consuming = false
			return
		end
		consuming = true
		local args = table.remove(queue, 1)
		fn(vim.F.unpack_len(args))
	end

	return function(...)
		local args = vim.F.pack_len(...)
		local cb = args[callback_arg_num]
		args[callback_arg_num] = function(...)
			local cb_args = vim.F.pack_len(...)
			vim.schedule(function()
				-- schedule the consumption first, the callback itself may fail
				vim.schedule(consume)
				cb(vim.F.unpack_len(cb_args))
			end)
		end
		table.insert(queue, args)
		if not consuming then
			consume()
		end
	end
end

return M
