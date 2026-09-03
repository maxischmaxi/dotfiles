-- Debugging (nvim-dap + dap-ui): the plugins are only added to the
-- runtimepath and set up on the first debug keymap, so a normal start pays
-- nothing for them.

local M = { loaded = false }

local mason_bin = vim.fn.stdpath("data") .. "/mason/bin/"

function M.setup()
	if M.loaded then
		return
	end
	M.loaded = true

	-- nvim-nio is a hard dependency of dap-ui
	vim.pack.add({
		"https://github.com/mfussenegger/nvim-dap",
		"https://github.com/nvim-neotest/nvim-nio",
		"https://github.com/rcarriga/nvim-dap-ui",
		"https://github.com/theHamsta/nvim-dap-virtual-text",
		"https://github.com/leoluz/nvim-dap-go",
	})

	local dap = require("dap")
	local dapui = require("dapui")

	-- codelldb speaks DAP over a socket, so it is launched as a server and nvim
	-- connects to the port it prints on startup
	dap.adapters.codelldb = {
		type = "server",
		port = "${port}",
		executable = {
			command = mason_bin .. "codelldb",
			args = { "--port", "${port}" },
		},
	}

	local function pick_executable()
		return coroutine.create(function(co)
			vim.ui.input({
				prompt = "Path to executable: ",
				default = vim.fn.getcwd() .. "/",
				completion = "file",
			}, function(input)
				coroutine.resume(co, input)
			end)
		end)
	end

	local native_config = {
		{
			name = "Launch executable",
			type = "codelldb",
			request = "launch",
			program = pick_executable,
			cwd = "${workspaceFolder}",
			stopOnEntry = false,
			args = {},
		},
		{
			name = "Attach to process",
			type = "codelldb",
			request = "attach",
			pid = require("dap.utils").pick_process,
			cwd = "${workspaceFolder}",
		},
	}

	dap.configurations.c = native_config
	dap.configurations.cpp = native_config
	dap.configurations.rust = native_config
	dap.configurations.odin = native_config

	-- delve adapter + the go launch configurations come from nvim-dap-go
	require("dap-go").setup({
		delve = { path = mason_bin .. "dlv" },
	})

	require("nvim-dap-virtual-text").setup({
		virt_text_pos = "eol",
		commented = true,
	})

	require("dapui").setup({
		icons = { expanded = "▾", collapsed = "▸", current_frame = "▸" },
		layouts = {
			{
				elements = {
					{ id = "scopes", size = 0.30 },
					{ id = "breakpoints", size = 0.20 },
					{ id = "stacks", size = 0.25 },
					{ id = "watches", size = 0.25 },
				},
				size = 44,
				position = "left",
			},
			{
				elements = {
					{ id = "repl", size = 0.5 },
					{ id = "console", size = 0.5 },
				},
				size = 12,
				position = "bottom",
			},
		},
	})

	-- open the ui when a session starts, close it when it ends
	dap.listeners.after.event_initialized["dapui_config"] = dapui.open
	dap.listeners.before.event_terminated["dapui_config"] = dapui.close
	dap.listeners.before.event_exited["dapui_config"] = dapui.close

	vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "DiagnosticSignError", numhl = "" })
	vim.fn.sign_define("DapBreakpointCondition", { text = "◆", texthl = "DiagnosticSignWarn", numhl = "" })
	vim.fn.sign_define("DapLogPoint", { text = "◉", texthl = "DiagnosticSignInfo", numhl = "" })
	vim.fn.sign_define("DapStopped", { text = "▶", texthl = "DiagnosticSignWarn", linehl = "Visual", numhl = "" })
end

-- Lightweight trigger keymaps: the first press loads dap + dap-ui and then
-- runs the actual action.
local set = vim.keymap.set

-- function keys for step control (layout independent), <leader>b for breakpoints
set("n", "<F5>", function()
	M.setup()
	require("dap").continue()
end, { desc = "Debug: start / continue" })
set("n", "<F9>", function()
	M.setup()
	require("dap").toggle_breakpoint()
end, { desc = "Debug: toggle breakpoint" })
set("n", "<F10>", function()
	M.setup()
	require("dap").step_over()
end, { desc = "Debug: step over" })
set("n", "<F11>", function()
	M.setup()
	require("dap").step_into()
end, { desc = "Debug: step into" })
set("n", "<F12>", function()
	M.setup()
	require("dap").step_out()
end, { desc = "Debug: step out" })
set("n", "<leader>b", function()
	M.setup()
	require("dap").toggle_breakpoint()
end, { desc = "Debug: toggle [B]reakpoint" })
set("n", "<leader>B", function()
	M.setup()
	vim.ui.input({ prompt = "Breakpoint condition: " }, function(cond)
		if cond then
			require("dap").set_breakpoint(cond)
		end
	end)
end, { desc = "Debug: conditional [B]reakpoint" })
set("n", "<leader>dl", function()
	M.setup()
	vim.ui.input({ prompt = "Log point message: " }, function(msg)
		if msg then
			require("dap").set_breakpoint(nil, nil, msg)
		end
	end)
end, { desc = "Debug: [L]og point" })
set("n", "<leader>du", function()
	M.setup()
	require("dapui").toggle()
end, { desc = "Debug: toggle [U]I" })
set("n", "<leader>dt", function()
	M.setup()
	require("dap").terminate()
end, { desc = "Debug: [T]erminate session" })
set("n", "<leader>dc", function()
	M.setup()
	require("dap").run_to_cursor()
end, { desc = "Debug: run to [C]ursor" })
set("n", "<leader>dR", function()
	M.setup()
	require("dap").restart()
end, { desc = "Debug: [R]estart session" })
set("n", "<leader>db", function()
	M.setup()
	require("dap").list_breakpoints()
end, { desc = "Debug: list [B]reakpoints in quickfix" })
set({ "n", "v" }, "<leader>dh", function()
	M.setup()
	require("dap.ui.widgets").hover()
end, { desc = "Debug: [H]over value" })

return M