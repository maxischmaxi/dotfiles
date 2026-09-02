local M = {}

local function tmux_yabai_or_split_switch(wincmd, direction)
	local previous_winnr = vim.api.nvim_get_current_win()
	vim.cmd("silent! wincmd " .. wincmd)
	local current_winnr = vim.api.nvim_get_current_win()
	if previous_winnr == current_winnr then
		if vim.fn.executable("tmux-window-navigation.sh") == 1 then
			os.execute("tmux-window-navigation.sh " .. direction)
		end
	end
end

M.tmux_yabai_or_split_switch = tmux_yabai_or_split_switch

vim.api.nvim_create_autocmd("FileType", {
	pattern = { "oil", "netrw" },
	callback = function()
		vim.keymap.set("n", "<C-h>", function()
			tmux_yabai_or_split_switch("h", "west")
		end, { buffer = true, desc = "Open parent directory" })
		vim.keymap.set("n", "<C-j>", function()
			tmux_yabai_or_split_switch("j", "south")
		end, { buffer = true, desc = "Open file" })
		vim.keymap.set("n", "<C-k>", function()
			tmux_yabai_or_split_switch("k", "north")
		end, { buffer = true, desc = "Open file" })
		vim.keymap.set("n", "<C-l>", function()
			tmux_yabai_or_split_switch("l", "east")
		end, { buffer = true, desc = "Open file" })
	end,
})

vim.keymap.set("n", "<C-h>", function()
	tmux_yabai_or_split_switch("h", "west")
end, { silent = true })
vim.keymap.set("n", "<C-j>", function()
	tmux_yabai_or_split_switch("j", "south")
end, { silent = true })
vim.keymap.set("n", "<C-k>", function()
	tmux_yabai_or_split_switch("k", "north")
end, { silent = true })
vim.keymap.set("n", "<C-l>", function()
	tmux_yabai_or_split_switch("l", "east")
end, { silent = true })

return M