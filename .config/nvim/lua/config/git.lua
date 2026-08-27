require("gitsigns").setup({
	-- german layout: [ and ] are AltGr+8/9, so hunk navigation lives on <leader>g
	-- and follows the existing <leader>{scope}{n,p} pattern (dn/dp, cn/cp)
	on_attach = function(bufnr)
		local gs = require("gitsigns")
		local map = function(mode, keys, func, desc)
			vim.keymap.set(mode, keys, func, { buffer = bufnr, desc = "Git: " .. desc })
		end

		map("n", "<leader>gn", function()
			-- in a diff buffer the plugin has no hunks, fall back to vim's own ]c
			if vim.wo.diff then
				vim.cmd.normal({ "]c", bang = true })
			else
				gs.nav_hunk("next")
			end
		end, "Next hunk")

		map("n", "<leader>gp", function()
			if vim.wo.diff then
				vim.cmd.normal({ "[c", bang = true })
			else
				gs.nav_hunk("prev")
			end
		end, "Previous hunk")

		map("n", "<leader>gs", gs.stage_hunk, "Stage hunk")
		map("n", "<leader>gr", gs.reset_hunk, "Reset hunk")
		map("v", "<leader>gs", function()
			gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
		end, "Stage selected lines")
		map("v", "<leader>gr", function()
			gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
		end, "Reset selected lines")

		map("n", "<leader>gS", gs.stage_buffer, "Stage buffer")
		map("n", "<leader>gR", gs.reset_buffer, "Reset buffer")
		map("n", "<leader>gv", gs.preview_hunk, "Preview hunk (float)")
		map("n", "<leader>gV", gs.preview_hunk_inline, "Preview hunk (inline)")
		map("n", "<leader>gb", function()
			gs.blame_line({ full = true })
		end, "Blame line (full)")
		map("n", "<leader>gB", gs.toggle_current_line_blame, "Toggle inline blame")
		map("n", "<leader>gd", gs.diffthis, "Diff against index")
		map("n", "<leader>gD", function()
			gs.diffthis("@")
		end, "Diff against HEAD")
		map("n", "<leader>gx", gs.toggle_deleted, "Toggle deleted lines")

		-- ih = "inner hunk", works with d/y/c like any other text object
		map({ "o", "x" }, "ih", gs.select_hunk, "Select hunk")
	end,
})

-- fugitive: the status buffer is the entry point for everything gitsigns can't do
vim.keymap.set("n", "<leader>gg", "<cmd>Git<CR>", { desc = "Git: fugitive status" })