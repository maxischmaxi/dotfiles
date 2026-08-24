local default_config = {
	input = {
		-- Set to false to disable the vim.ui.input implementation
		enabled = true,

		-- Default prompt string
		default_prompt = "Input",

		-- Trim trailing `:` from prompt
		trim_prompt = true,

		-- Can be 'left', 'right', or 'center'
		title_pos = "left",

		-- The initial mode when the window opens (insert|normal|visual|select)
		start_mode = "insert",

		-- nil inherits the global 'winborder'
		border = nil,

		-- 'editor' and 'win' will default to being centered
		relative = "cursor",

		-- Derive `relative` from opts.scope when the caller sets one (nvim 0.13)
		use_scope = true,

		-- These can be integers or a float between 0 and 1 (e.g. 0.4 for 40%).
		-- min_width and max_width can be a list of mixed types:
		-- min_width = {20, 0.2} means "the greater of 20 columns or 20% of total"
		prefer_width = 40,
		width = nil,
		max_width = { 140, 0.9 },
		min_width = { 20, 0.2 },

		buf_options = {},
		win_options = {
			wrap = false,
			-- Indicator for when text exceeds the window
			list = true,
			listchars = "precedes:…,extends:…",
			sidescrolloff = 0,
		},

		-- Set to `false` to disable. Values are action names or functions.
		mappings = {
			n = {
				["<Esc>"] = "Close",
				["<CR>"] = "Confirm",
			},
			i = {
				["<C-c>"] = "Close",
				["<CR>"] = "Confirm",
				["<Up>"] = "HistoryPrev",
				["<Down>"] = "HistoryNext",
			},
		},

		-- Receives the config that is passed to nvim_open_win
		override = function(conf)
			return conf
		end,

		-- fun(opts): table? — per-call config override
		get_config = nil,
	},
	select = {
		-- Set to false to disable the vim.ui.select implementation
		enabled = true,

		-- Priority list of preferred vim.ui.select implementations
		backend = { "telescope", "builtin" },

		-- Trim trailing `:` from prompt
		trim_prompt = true,

		-- Passed into the telescope picker directly. nil means the backend
		-- falls back to themes.get_dropdown()
		telescope = nil,

		builtin = {
			-- Display numbers for options and set up keymaps
			show_numbers = true,

			-- nil inherits the global 'winborder'
			border = nil,
			title_pos = "center",

			-- 'editor' and 'win' will default to being centered
			relative = "editor",

			buf_options = {},
			win_options = {
				cursorline = true,
				cursorlineopt = "both",
				-- disable highlighting for the brackets around the numbers
				winhighlight = "MatchParen:",
				-- adds padding at the left border
				statuscolumn = " ",
			},

			width = nil,
			max_width = { 140, 0.8 },
			min_width = { 40, 0.2 },
			height = nil,
			max_height = 0.9,
			min_height = { 10, 0.2 },

			-- Set to `false` to disable
			mappings = {
				["<Esc>"] = "Close",
				["<C-c>"] = "Close",
				["<CR>"] = "Confirm",
			},

			override = function(conf)
				return conf
			end,
		},

		-- Override format_item per opts.kind
		format_item_override = {},

		-- fun(opts, items): table? — per-call config override
		get_config = nil,
	},
}

local M = vim.deepcopy(default_config)

M.update = function(opts)
	local newconf = vim.tbl_deep_extend("force", default_config, opts or {})
	for k, v in pairs(newconf) do
		M[k] = v
	end
end

---Effective config for a module, applying its get_config hook
---@param key string
---@return table
M.get_mod_config = function(key, ...)
	if not M[key].get_config then
		return M[key]
	end
	local conf = M[key].get_config(...)
	if conf then
		return vim.tbl_deep_extend("force", M[key], conf)
	end
	return M[key]
end

return M
