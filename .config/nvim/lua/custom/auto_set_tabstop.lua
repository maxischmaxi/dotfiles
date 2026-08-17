local M = {}

local cache = {}

local function read_file(path)
	local fd = vim.uv.fs_open(path, "r", 438)
	if not fd then
		return nil
	end
	local stat = vim.uv.fs_fstat(fd)
	local data = vim.uv.fs_read(fd, stat.size, 0)
	vim.uv.fs_close(fd)
	return data
end

local function json_decode(s)
	local ok, val = pcall(vim.json.decode, s)
	if ok then
		return val
	end
	return nil
end

local function dirname(p)
	return vim.fs.dirname(p)
end

local function find_prettier_config(startpath)
	local candidates = {
		"package.json",
		".prettierrc",
		".prettierrc.json",
		".prettierrc.yml",
		".prettierrc.yaml",
		"prettier.config.js",
	}

	local found = vim.fs.find(candidates, {
		path = startpath,
		upward = true,
		type = "file",
	})

	if #found == 0 then
		return nil
	end
	local priority = {}
	for i, name in ipairs(candidates) do
		priority[name] = i
	end

	local best, best_prio = nil, 1e9
	for _, p in ipairs(found) do
		local base = p:match("[^/\\]+$") or p
		local pr = priority[base] or 9999
		if pr < best_prio then
			best, best_prio = p, pr
		end
	end
	return best
end

local function load_prettier_via_node(path)
	local cmd = { "node", vim.fn.expand("~/.config/nvim/scripts/read-prettier.js"), path }
	local out = vim.fn.system(cmd)
	if vim.v.shell_error ~= 0 or not out or out == "" then
		return nil
	end
	return json_decode(out)
end

local function load_prettier_from_path(path)
	local base = path:match("[^/\\]+$") or path
	local text = read_file(path)
	if not text then
		return nil
	end

	-- package.json: "prettier" kann Objekt ODER Pfad sein
	if base == "package.json" then
		local pkg = json_decode(text)
		if not pkg then
			return nil
		end
		local prettier = pkg.prettier
		if type(prettier) == "table" then
			return prettier
		elseif type(prettier) == "string" then
			-- relativen Pfad auflösen und (nur JSON) laden
			local cfg_path = vim.fs.normalize(dirname(path) .. "/" .. prettier)
			local cfg_txt = read_file(cfg_path)
			if not cfg_txt then
				return nil
			end
			local cfg = json_decode(cfg_txt)
			return cfg
		else
			return nil
		end
	end

	-- .prettierrc / .prettierrc.json (JSON)
	if base == ".prettierrc" or base == ".prettierrc.json" then
		return json_decode(text)
	end

	-- .prettierrc.yml / .prettierrc.yaml (YAML)
	if base:match("%.ya?ml$") or base:match("%.js$") then
		-- YAML via Node laden (Lua/YAML-Parser nicht immer verfügbar)
		return load_prettier_via_node(path)
	end

	return nil
end

local function find_project_root(startpath, cfg_path)
	-- Versuch Git-Root
	local git_root = vim.fs.find(".git", { path = startpath, upward = true, type = "directory" })[1]
	if git_root then
		return dirname(git_root)
	end
	-- Sonst Ordner der Config
	if cfg_path then
		return dirname(cfg_path)
	end
	-- Fallback: Ordner der Datei
	return dirname(startpath)
end

local function apply_indent(buf, opts)
	local tw = 4 -- Default auf 4
	local useTabs = false

	if opts then
		tw = tonumber(opts.tabWidth) or tw
		if opts.useTabs ~= nil then
			useTabs = opts.useTabs
		end
	end

	-- Lokal für diesen Buffer setzen
	vim.bo[buf].expandtab = not useTabs
	vim.bo[buf].tabstop = tw
	vim.bo[buf].shiftwidth = tw
	vim.bo[buf].softtabstop = tw
end

local function compute_opts_for_buf(buf)
	local name = vim.api.nvim_buf_get_name(buf)
	if name == "" then
		return nil
	end
	local startpath = dirname(name)
	if not startpath then
		return nil
	end

	-- Falls Root bereits gecached ist, nutze Cache
	-- (Root zuerst ermitteln, dann Cache prüfen)
	local cfg_path = find_prettier_config(startpath)
	if not cfg_path then
		return nil
	end

	local root = find_project_root(startpath, cfg_path)
	if cache[root] ~= nil then
		return cache[root]
	end

	local cfg = load_prettier_from_path(cfg_path)

	-- Ergebnis cachen (auch nil, damit wir nicht ständig erneut parsen)
	cache[root] = cfg or false
	return cache[root] or nil
end

-- Autocmd: beim Buffer-Betreten anwenden
local group = vim.api.nvim_create_augroup("PrettierIndentSync", { clear = true })
vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
	group = group,
	callback = function(args)
		local opts = compute_opts_for_buf(args.buf)
		apply_indent(args.buf, opts)
	end,
})

-- Optional: einmal beim Start auf aktuellem Buffer und global setzen
vim.api.nvim_create_autocmd("VimEnter", {
	group = group,
	callback = function()
		local buf = vim.api.nvim_get_current_buf()
		local opts = compute_opts_for_buf(buf)
		
		-- Wenn eine Prettier-Config im CWD gefunden wurde, global setzen
		if opts then
			local tw = tonumber(opts.tabWidth) or 4
			local useTabs = opts.useTabs
			if useTabs ~= nil then
				vim.o.expandtab = not useTabs
			end
			if tw then
				vim.o.tabstop = tw
				vim.o.shiftwidth = tw
				vim.o.softtabstop = tw
			end
		end
		
		apply_indent(buf, opts)
	end,
})
