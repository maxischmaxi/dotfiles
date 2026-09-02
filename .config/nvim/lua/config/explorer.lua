-- File explorer. The backend is chosen by vim.g.file_explorer in config.options:
--   "netrw" -> built-in, no plugin
--   "oil"   -> oil.nvim, which config.pack only downloads for that value
-- Both bind <C-b> to "browse the directory of the current file in this window".

if vim.g.file_explorer == "oil" then
	require("oil").setup({
		default_file_explorer = true,
		columns = {
			"icon",
			"size",
			"mtime",
		},
		buf_options = {
			buflisted = false,
			bufhidden = "hide",
		},
		win_options = {
			wrap = false,
			signcolumn = "no",
			cursorcolumn = false,
			foldcolumn = "0",
			spell = false,
			list = false,
			conceallevel = 3,
			concealcursor = "nvic",
		},
		delete_to_trash = false,
		skip_confirm_for_simple_edits = true,
		prompt_save_on_select_new_entry = true,
		cleanup_delay_ms = 2000,
		lsp_file_methods = {
			enabled = true,
			timeout_ms = 1000,
			autosave_changes = false,
		},
		constrain_cursor = "editable",
		watch_for_changes = false,
		keymaps = {
			["="] = "actions.refresh",
		},
		use_default_keymaps = true,
		view_options = {
			show_hidden = true,
		},
	})

	vim.keymap.set("n", "<C-b>", "<CMD>Oil<CR>", { desc = "Open file explorer" })
	return
end

-- netrw ----------------------------------------------------------------------

vim.g.netrw_banner = 0 -- the 8 line header eats the top of every listing
vim.g.netrw_liststyle = 1 -- name + size + mtime, the closest match to oil's columns
vim.g.netrw_sizestyle = "H" -- human readable, 1024 based
vim.g.netrw_timefmt = "  %Y-%m-%d %H:%M" -- default is the locale's long form
vim.g.netrw_browse_split = 0 -- <CR> opens in the netrw window, like oil
vim.g.netrw_fastbrowse = 0 -- always re-read the directory, never show a stale listing
vim.g.netrw_keepdir = 1 -- browsing must not move :pwd out from under telescope/lsp
vim.g.netrw_localcopydircmd = "cp -r" -- mc on a directory fails without this
vim.g.netrw_sort_options = "i" -- case insensitive
vim.g.netrw_altfile = 1 -- keep the edited file as #, not the netrw buffer

-- buffer the explorer was opened from, so <C-b> can toggle back to it
local origin = nil

local function back()
	if origin and vim.api.nvim_buf_is_valid(origin) and vim.bo[origin].filetype ~= "netrw" then
		vim.api.nvim_set_current_buf(origin)
	elseif vim.fn.bufnr("#") > 0 then
		vim.cmd.buffer("#")
	end
end

-- netrw parks the cursor on "../"; oil puts it on the file you came from
local function cursor_to(name)
	if name == "" then
		return
	end
	for i, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
		-- long listing is the name padded out to the size/mtime columns
		local rest = line:sub(#name + 1)
		if line:sub(1, #name) == name and (rest == "" or rest:match("^[%s/]")) then
			vim.api.nvim_win_set_cursor(0, { i, 0 })
			return
		end
	end
end

local function browse()
	if vim.bo.filetype == "netrw" then
		return back()
	end
	origin = vim.api.nvim_get_current_buf()
	local name = vim.fn.expand("%:t")
	vim.cmd("Explore")
	cursor_to(name)
end

vim.keymap.set("n", "<C-b>", browse, { desc = "Open file explorer" })

-- netrw v184 no longer hijacks directory buffers, so `nvim .` and `:edit <dir>`
-- just leave an empty ft=directory buffer behind. Browse it, like oil did.
vim.api.nvim_create_autocmd("FileType", {
	group = vim.api.nvim_create_augroup("custom-netrw-dir", { clear = true }),
	pattern = "directory",
	callback = function(ev)
		local dir = vim.api.nvim_buf_get_name(ev.buf)
		vim.schedule(function()
			if vim.api.nvim_get_current_buf() ~= ev.buf then
				return
			end
			vim.cmd("Explore " .. vim.fn.fnameescape(dir))
			if vim.api.nvim_buf_is_valid(ev.buf) and vim.api.nvim_get_current_buf() ~= ev.buf then
				vim.api.nvim_buf_delete(ev.buf, { force = true })
			end
		end)
	end,
})

vim.api.nvim_create_autocmd("FileType", {
	group = vim.api.nvim_create_augroup("custom-netrw", { clear = true }),
	pattern = "netrw",
	callback = function(ev)
		-- netrw fires FileType after its own maps, so these override them
		local opts = { buffer = ev.buf, silent = true }
		vim.keymap.set("n", "<C-b>", back, opts)
		vim.keymap.set("n", "<C-c>", back, opts)
		vim.keymap.set("n", "=", "<Plug>NetrwRefresh", { buffer = ev.buf, remap = true })
		vim.keymap.set("n", "g?", "<Cmd>help netrw-quickmap<CR>", opts)

		vim.opt_local.signcolumn = "no"
		vim.opt_local.foldcolumn = "0"
		vim.opt_local.colorcolumn = ""
		vim.opt_local.list = false
		vim.opt_local.spell = false
		vim.opt_local.wrap = false
		vim.opt_local.cursorline = true
	end,
})
