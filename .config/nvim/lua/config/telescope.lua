require("telescope").setup({
	defaults = {
		preview = {
			filesize_limit = 10,
			mime_hook = function(fp, bufnr, opts)
				local is_image = function(filepath)
					local image_extensions = { "png", "jpg" } -- Supported image formats
					local split_path = vim.split(filepath:lower(), ".", { plain = true })
					local extension = split_path[#split_path]
					return vim.tbl_contains(image_extensions, extension)
				end
				if is_image(fp) and vim.fn.executable("catimg") == 1 then
					local term = vim.api.nvim_open_term(bufnr, {})
					local function send_output(_, data, _)
						for _, d in ipairs(data) do
							vim.api.nvim_chan_send(term, d .. "\r\n")
						end
					end
					vim.fn.jobstart({
						"catimg",
						"-w",
						"100",
						"-r",
						"2",
						fp,
					}, {
						on_stdout = send_output,
						stdout_buffered = true,
						pty = true,
					})
				else
					local message = is_image(fp) and "catimg not found: image preview disabled"
						or "Binary cannot be previewed"
					require("telescope.previewers.utils").set_preview_message(bufnr, opts.winid, message)
				end
			end,
		},
		layout_config = { width = 0.9, height = 0.9 },
		file_ignore_patterns = {
			"node_modules/",
			"%.git/",
			"%.tsbuildinfo$",
			"__image%-snapshots__/",
			"%.o$",
			"%.a$",
			"%.out$",
			"%.obj$",
			"%.gch$",
			"%.pch$",
		},
	},
	pickers = {
		find_files = {
			hidden = true,
			find_command = {
				"rg",
				"--files",
				"--hidden",
				"--glob",
				"!**/.git/*",
			},
		},
	},
	extensions = {
		fzf = {
			fuzzy = true,
			override_generic_sorter = true,
			override_file_sorter = true,
			case_mode = "smart_case",
		},
	},
})

require("telescope").load_extension("fzf")

-- require lazily so telescope.builtin is not pulled in at startup
local pick = function(name, opts)
	return function()
		require("telescope.builtin")[name](opts)
	end
end

vim.keymap.set("n", "<leader>sf", pick("find_files"), { desc = "[S]earch [F]iles" })
vim.keymap.set("n", "<leader>sg", pick("live_grep"), { desc = "[S]earch by [G]rep" })
vim.keymap.set("n", "<leader>sh", pick("help_tags"), { desc = "[S]earch [H]elp" })
vim.keymap.set("n", "<leader>sk", pick("keymaps"), { desc = "[S]earch [K]eymaps" })
vim.keymap.set("n", "<leader>sd", pick("diagnostics"), { desc = "[S]earch [D]iagnostics" })
vim.keymap.set("n", "<leader>sr", pick("resume"), { desc = "[S]earch [R]esume last picker" })
vim.keymap.set("n", "<leader>s.", pick("oldfiles"), { desc = "[S]earch recent files" })
vim.keymap.set("n", "<leader>ss", pick("lsp_document_symbols"), { desc = "[S]earch document [S]ymbols" })
vim.keymap.set("n", "<leader>sS", pick("lsp_dynamic_workspace_symbols"), { desc = "[S]earch workspace [S]ymbols" })
vim.keymap.set("n", "<leader>st", pick("builtin"), { desc = "[S]earch [T]elescope pickers" })
vim.keymap.set("n", "<leader>sc", pick("commands"), { desc = "[S]earch [C]ommands" })
vim.keymap.set("n", "<leader>sm", pick("marks"), { desc = "[S]earch [M]arks" })
vim.keymap.set("n", "<leader>sq", pick("quickfix"), { desc = "[S]earch [Q]uickfix list" })
vim.keymap.set("n", "<leader>sj", pick("jumplist"), { desc = "[S]earch [J]umplist" })
vim.keymap.set("n", "<leader><leader>", pick("buffers"), { desc = "Find existing buffers" })

-- search only inside the current buffer
vim.keymap.set("n", "<leader>/", function()
	require("telescope.builtin").current_buffer_fuzzy_find(
		require("telescope.themes").get_dropdown({ winblend = 10, previewer = false })
	)
end, { desc = "Fuzzy search in current buffer" })

-- grep the word/selection under the cursor
vim.keymap.set("n", "<leader>*", pick("grep_string"), { desc = "Grep word under cursor" })
vim.keymap.set("v", "<leader>*", pick("grep_string"), { desc = "Grep visual selection" })

vim.keymap.set("n", "<leader>gf", pick("git_status"), { desc = "Git: status picker" })
vim.keymap.set("n", "<leader>gc", pick("git_commits"), { desc = "Git: commit log" })
vim.keymap.set("n", "<leader>gh", pick("git_bcommits"), { desc = "Git: commits for this file" })
vim.keymap.set("n", "<leader>gt", pick("git_branches"), { desc = "Git: branches" })

vim.keymap.set("n", "gd", pick("lsp_definitions"), { desc = "[G]oto [D]efinition" })
vim.keymap.set("n", "gr", pick("lsp_references"), { desc = "[G]oto [R]eferences" })
vim.keymap.set("n", "gI", pick("lsp_implementations"), { desc = "[G]oto [I]mplementation" })
vim.keymap.set("n", "gy", pick("lsp_type_definitions"), { desc = "[G]oto t[y]pe definition" })
vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, { desc = "[R]e[n]ame" })