-- C-h/j/k/l: move between nvim splits, and at the edge hand over to tmux
-- (tmux-window-navigation.sh, on the PATH via ~/dotfiles).
local M = {}

local function tmux_yabai_or_split_switch(wincmd, direction)
	local previous_winnr = vim.api.nvim_get_current_win()
	vim.cmd("silent! wincmd " .. wincmd)
	if previous_winnr ~= vim.api.nvim_get_current_win() then
		return
	end
	-- vim.system instead of os.execute: no shell, and nvim is not blocked
	if vim.fn.executable("tmux-window-navigation.sh") == 1 then
		vim.system({ "tmux-window-navigation.sh", direction })
	end
end
M.tmux_yabai_or_split_switch = tmux_yabai_or_split_switch

local directions = { h = "west", j = "south", k = "north", l = "east" }

local function map(buffer)
	for key, direction in pairs(directions) do
		vim.keymap.set("n", "<C-" .. key .. ">", function()
			tmux_yabai_or_split_switch(key, direction)
		end, { silent = true, buffer = buffer, desc = "Window " .. direction })
	end
end

-- netrw/oil define their own <C-h>/<C-l> buffer maps, so the navigation is
-- re-applied on top of them
vim.api.nvim_create_autocmd("FileType", {
	group = vim.api.nvim_create_augroup("custom-tmux-navigator", { clear = true }),
	pattern = { "oil", "netrw" },
	callback = function(ev)
		map(ev.buf)
	end,
})

map()

return M
