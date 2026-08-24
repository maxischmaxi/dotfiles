local M = {}

M.check = function()
	vim.health.start("dressing")

	local patch = require("dressing.patch")
	for _, name in ipairs(patch.all_modules) do
		if patch.original_mods[name] then
			local enabled = patch.is_enabled(name) and "enabled" or "disabled (delegating to the original)"
			vim.health.ok(string.format("vim.ui.%s is patched, %s", name, enabled))
		else
			vim.health.warn(string.format("vim.ui.%s is not patched, call require('dressing').setup()", name))
		end
	end

	local config = require("dressing.config")
	local _, backend = require("dressing.select").get_backend(config.select.backend)
	vim.health.ok(string.format("select backend: %s", backend))
end

return M
