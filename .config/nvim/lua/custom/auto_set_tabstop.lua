-- Sync tabstop/shiftwidth/expandtab with the project's prettier config
-- (tabWidth/useTabs). Resolution walks upward like prettier does: the first
-- config file wins, a package.json only counts with a "prettier" key.
local M = {}

-- resolved options per starting directory, false = nothing found
local cache = {}

local candidates = {
	"package.json",
	".prettierrc",
	".prettierrc.json",
	".prettierrc.yml",
	".prettierrc.yaml",
	"prettier.config.js",
}

-- yaml and js configs are read through node
local reader = vim.fs.joinpath(vim.fn.stdpath("config"), "scripts", "read-prettier.js")

local function read_file(path)
	local fd = vim.uv.fs_open(path, "r", 438)
	if not fd then
		return nil
	end
	local stat = vim.uv.fs_fstat(fd)
	local data = stat and vim.uv.fs_read(fd, stat.size, 0) or nil
	vim.uv.fs_close(fd)
	return data
end

local function read_json(path)
	local text = read_file(path)
	if not text then
		return nil
	end
	local ok, val = pcall(vim.json.decode, text)
	return ok and type(val) == "table" and val or nil
end

-- async, so opening a file never waits for node
local function read_via_node(path, cb)
	if vim.fn.executable("node") ~= 1 then
		return cb(nil)
	end
	vim.system({ "node", reader, path }, { text = true }, function(res)
		local ok, val = pcall(vim.json.decode, res.stdout or "")
		cb(res.code == 0 and ok and type(val) == "table" and val or nil)
	end)
end

-- calls cb with the options table, or nil when no config applies
local function resolve(dir, cb)
	local prev
	while dir ~= prev do
		for _, name in ipairs(candidates) do
			local path = vim.fs.joinpath(dir, name)
			if vim.uv.fs_stat(path) then
				if name == "package.json" then
					local pkg = read_json(path)
					local prettier = pkg and pkg.prettier
					if type(prettier) == "table" then
						return cb(prettier)
					elseif type(prettier) == "string" then
						-- a relative path to a json config
						return cb(read_json(vim.fs.normalize(vim.fs.joinpath(dir, prettier))))
					end
					-- no prettier key: keep walking
				elseif name == ".prettierrc" or name == ".prettierrc.json" then
					return cb(read_json(path))
				else
					return read_via_node(path, cb)
				end
			end
		end
		prev, dir = dir, vim.fs.dirname(dir)
	end
	cb(nil)
end

local function lookup(dir, cb)
	if cache[dir] ~= nil then
		return cb(cache[dir] or nil)
	end
	resolve(dir, function(opts)
		cache[dir] = opts or false
		cb(opts)
	end)
end

-- without a config the previous defaults stay: width 4, spaces
local function apply(buf, opts)
	if not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	local width = opts and tonumber(opts.tabWidth) or 4
	local use_tabs = opts ~= nil and opts.useTabs == true
	vim.bo[buf].expandtab = not use_tabs
	vim.bo[buf].tabstop = width
	vim.bo[buf].shiftwidth = width
	vim.bo[buf].softtabstop = width
end

local group = vim.api.nvim_create_augroup("PrettierIndentSync", { clear = true })

vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
	group = group,
	callback = function(ev)
		local name = vim.api.nvim_buf_get_name(ev.buf)
		if name == "" then
			return
		end
		lookup(vim.fs.dirname(name), function(opts)
			vim.schedule(function()
				apply(ev.buf, opts)
			end)
		end)
	end,
})

-- a config in the cwd also sets the globals, so new buffers pick it up
vim.api.nvim_create_autocmd("VimEnter", {
	group = group,
	callback = function()
		local buf = vim.api.nvim_get_current_buf()
		lookup(vim.fn.getcwd(), function(opts)
			vim.schedule(function()
				if opts then
					local width = tonumber(opts.tabWidth) or 4
					if opts.useTabs ~= nil then
						vim.o.expandtab = not opts.useTabs
					end
					vim.o.tabstop = width
					vim.o.shiftwidth = width
					vim.o.softtabstop = width
				end
				apply(buf, opts)
			end)
		end)
	end,
})

return M
