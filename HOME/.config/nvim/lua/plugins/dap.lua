pcall(vim.cmd.packadd, "nvim-nio")

local function require_plugin(module)
  local status_ok, plugin = pcall(require, module)
  if status_ok then
    return plugin
  end

  vim.notify("Skipping DAP setup: missing " .. module, vim.log.levels.WARN)
  return nil
end

local dap = require_plugin('dap')
local dapui = require_plugin('dapui')
local dap_virtual_text = require_plugin('nvim-dap-virtual-text')
local dap_python = require_plugin('dap-python')

if not dap or not dapui or not dap_virtual_text or not dap_python then
  return
end

dap_virtual_text.setup()

-- Set up DAP UI
dapui.setup()

-- Key mappings for DAP
vim.fn.sign_define('DapBreakpoint', {text='🔴', texthl='', linehl='', numhl=''})
vim.fn.sign_define('DapStopped', {text='➡️', texthl='', linehl='', numhl=''})

-- Basic keymaps
vim.api.nvim_set_keymap('n', '<F5>', [[<Cmd>lua require'dap'.continue()<CR>]], { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<F10>', [[<Cmd>lua require'dap'.step_over()<CR>]], { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<F11>', [[<Cmd>lua require'dap'.step_into()<CR>]], { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<F12>', [[<Cmd>lua require'dap'.step_out()<CR>]], { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<Leader>b', [[<Cmd>lua require'dap'.toggle_breakpoint()<CR>]], { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<Leader>B', [[<Cmd>lua require'dap'.set_breakpoint(vim.fn.input('Breakpoint condition: '))<CR>]], { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<Leader>lp', [[<Cmd>lua require'dap'.set_breakpoint(nil, nil, vim.fn.input('Log point message: '))<CR>]], { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<Leader>dr', [[<Cmd>lua require'dap'.repl.open()<CR>]], { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<Leader>dl', [[<Cmd>lua require'dap'.run_last()<CR>]], { noremap = true, silent = true })

-- Automatically open DAP UI when debugging starts
dap.listeners.after.event_initialized["dapui_config"] = function()
  dapui.open()
end

-- Automatically close DAP UI when debugging stops
dap.listeners.before.event_terminated["dapui_config"] = function()
  dapui.close()
end

dap.listeners.before.event_exited["dapui_config"] = function()
  dapui.close()
end

dap_python.setup('~/.local/share/nvim/mason/packages/debugpy/venv/bin/python') -- Adjust the path to your virtual environment

-- Keymaps for Python debugging
vim.api.nvim_set_keymap('n', '<Leader>dn', [[<Cmd>lua require('dap-python').test_method()<CR>]], { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<Leader>df', [[<Cmd>lua require('dap-python').test_class()<CR>]], { noremap = true, silent = true })
vim.api.nvim_set_keymap('v', '<Leader>ds', [[<Cmd>lua require('dap-python').debug_selection()<CR>]], { noremap = true, silent = true })
