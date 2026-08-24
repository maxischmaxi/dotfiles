local patch = require("dressing.patch")

local M = {}

local function set_highlights()
	vim.api.nvim_set_hl(0, "DressingSelectIdx", { link = "Special" })
end

M.setup = function(opts)
	require("dressing.config").update(opts)

	set_highlights()
	local group = vim.api.nvim_create_augroup("Dressing", { clear = true })
	vim.api.nvim_create_autocmd("ColorScheme", {
		desc = "Restore dressing highlights after a colorscheme switch",
		group = group,
		callback = set_highlights,
	})

	M.patch()
end

---Patch all the vim.ui methods
M.patch = function()
	patch.patch()
end

---Unpatch the vim.ui methods
---@param names? string|string[] Names of vim.ui modules to unpatch
M.unpatch = function(names)
	if not names then
		names = patch.all_modules
	elseif type(names) ~= "table" then
		names = { names }
	end
	for _, name in ipairs(names) do
		patch.mod(name, false)
	end
end

return M
