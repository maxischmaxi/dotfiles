local all_modules = { "input", "select" }

local M = {}

local enabled_mods = {}
-- Tracks the wrapper we installed per module. Function objects can't carry
-- fields, so the sentinel lives here instead of on the wrapper itself.
local wrapped = {}

M.original_mods = {}

---@param key string
---@return boolean?
M.is_enabled = function(key)
	local enabled = enabled_mods[key]
	if enabled == nil then
		enabled = require("dressing.config")[key].enabled
	end
	return enabled
end

---Patch the vim.ui methods, keeping the previous implementation as a fallback
---@param names? string[]
M.patch = function(names)
	for _, key in ipairs(names or all_modules) do
		-- Re-sourcing init.lua would otherwise stack wrappers on each other
		if wrapped[key] ~= vim.ui[key] then
			M.original_mods[key] = vim.ui[key]
			local wrapper = function(...)
				if M.is_enabled(key) then
					return require(string.format("dressing.%s", key))(...)
				else
					return M.original_mods[key](...)
				end
			end
			vim.ui[key] = wrapper
			wrapped[key] = wrapper
		end
	end
end

---@param name string
---@param enabled? boolean When nil, use the default from config
M.mod = function(name, enabled)
	enabled_mods[name] = enabled
end

M.all_modules = all_modules

return M
