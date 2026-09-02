local set = vim.keymap.set

set("n", "<leader>e", vim.diagnostic.open_float, { desc = "Open floating diagnostic message" })
set("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Open diagnostics list" })
set("n", "<leader>i", ":noh<CR>", { silent = true, desc = "hide search highlights" })
set("n", "<leader>dn", function()
	vim.diagnostic.jump({
		count = 1,
		severity = {
			min = vim.diagnostic.severity.INFO,
			max = vim.diagnostic.severity.ERROR,
		},
	})
end, { desc = "Next diagnostic" })
set("n", "<leader>dp", function()
	vim.diagnostic.jump({
		count = -1,
		severity = {
			min = vim.diagnostic.severity.INFO,
			max = vim.diagnostic.severity.ERROR,
		},
	})
end, { desc = "Previous diagnostic" })
set("n", "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })
set("n", "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })
set({ "n", "v" }, "<Space>", "<Nop>", { silent = true })
set("n", "n", "nzzzv")
set("n", "N", "Nzzzv")
set("n", "<c-d>", "<c-d>zz", { desc = "Scroll down half screen" })
set("n", "<c-u>", "<c-u>zz", { desc = "Scroll up half screen" })

set("n", "<leader>cn", "<cmd>cnext<CR>zz", { desc = "Go to next quickfix item" })
set("n", "<leader>cp", "<cmd>cprev<CR>zz", { desc = "Go to previous quickfix item" })

set("n", "<leader>+", ':exe "vertical resize " . (winwidth(0) * 4/1)<CR>', { silent = true })
set("n", "<leader>-", ':exe "vertical resize " . (winwidth(0) * 1/4)<CR>', { silent = true })

set("n", "gK", function()
	local ok, err = pcall(vim.cmd, "Man " .. vim.fn.expand("<cword>"))
	if not ok then
		vim.notify(err, vim.log.levels.WARN)
	end
end, { desc = "Open man page for word under cursor" })

-- tmux/yabai window navigation (C-h/j/k/l), frueher outside des Config-Dirs,
-- jetzt als Modul damit die Config self-contained ist
require("config.tmux_navigator")