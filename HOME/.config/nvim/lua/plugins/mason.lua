local lspconfig = require("lspconfig")

local function lsp_capabilities()
  local status_ok, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
  if not status_ok then
    return vim.lsp.protocol.make_client_capabilities()
  end

  return cmp_nvim_lsp.default_capabilities()
end

local function lsp_keymap_options(bufnr, description)
  return { buffer = bufnr, desc = description, silent = true }
end

local function set_lsp_keymaps(event)
  local bufnr = event.buf

  vim.keymap.set("n", "gd", vim.lsp.buf.definition, lsp_keymap_options(bufnr, "Go to definition"))
  vim.keymap.set("n", "gD", vim.lsp.buf.declaration, lsp_keymap_options(bufnr, "Go to declaration"))
  vim.keymap.set("n", "gi", vim.lsp.buf.implementation, lsp_keymap_options(bufnr, "Go to implementation"))
  vim.keymap.set("n", "gr", vim.lsp.buf.references, lsp_keymap_options(bufnr, "Go to references"))
  vim.keymap.set("n", "K", vim.lsp.buf.hover, lsp_keymap_options(bufnr, "Hover documentation"))
  vim.keymap.set("i", "<C-h>", vim.lsp.buf.signature_help, lsp_keymap_options(bufnr, "Signature help"))
end

vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("dotfiles_lsp_keymaps", { clear = true }),
  callback = set_lsp_keymaps,
})

local capabilities = lsp_capabilities()

require('mason').setup()
require('mason-lspconfig').setup {
  ensure_installed = { 'pyright', 'ruff' },
}
require('mason-lspconfig').setup_handlers {
  function(server_name)
    lspconfig[server_name].setup {
      capabilities = capabilities,
    }
  end,
}

require('mason-tool-installer').setup {

  -- a list of all tools you want to ensure are installed upon
  -- start
  ensure_installed = {

    -- you can pin a tool to a particular version
    -- { 'golangci-lint', version = 'v1.47.0' },

    -- you can turn off/on auto_update per tool
    -- { 'bash-language-server', auto_update = true },

    'pyright',
    'mypy',
    'autopep8',
    'flake8',
    'black',
    'ruff',
    'debugpy'

  },

  -- if set to true this will check each tool for updates. If updates
  -- are available the tool will be updated. This setting does not
  -- affect :MasonToolsUpdate or :MasonToolsInstall.
  -- Default: false
  auto_update = false,

  -- automatically install / update on startup. If set to false nothing
  -- will happen on startup. You can use :MasonToolsInstall or
  -- :MasonToolsUpdate to install tools and check for updates.
  -- Default: true
  run_on_start = true,

  -- set a delay (in ms) before the installation starts. This is only
  -- effective if run_on_start is set to true.
  -- e.g.: 5000 = 5 second delay, 10000 = 10 second delay, etc...
  -- Default: 0
  start_delay = 3000, -- 3 second delay

  -- Only attempt to install if 'debounce_hours' number of hours has
  -- elapsed since the last time Neovim was started. This stores a
  -- timestamp in a file named stdpath('data')/mason-tool-installer-debounce.
  -- This is only relevant when you are using 'run_on_start'. It has no
  -- effect when running manually via ':MasonToolsInstall' etc....
  -- Default: nil
  debounce_hours = 5, -- at least 5 hours between attempts to install/update

  -- By default all integrations are enabled. If you turn on an integration
  -- and you have the required module(s) installed this means you can use
  -- alternative names, supplied by the modules, for the thing that you want
  -- to install. If you turn off the integration (by setting it to false) you
  -- cannot use these alternative names. It also suppresses loading of those
  -- module(s) (assuming any are installed) which is sometimes wanted when
  -- doing lazy loading.
  integrations = {
    ['mason-lspconfig'] = true,
    ['mason-null-ls'] = true,
    ['mason-nvim-dap'] = true,
  },
}
