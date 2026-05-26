local ok, otter = pcall(require, "otter")
if not ok then
  return
end

local markdown_filetypes = {
  markdown = true,
  rmd = true,
}

local function current_buffer()
  return vim.api.nvim_get_current_buf()
end

local function is_markdown_buffer()
  return markdown_filetypes[vim.bo.filetype] == true
end

local function has_python_raft(bufnr)
  local ok, keeper = pcall(require, "otter.keeper")
  if not ok then
    return false
  end

  local raft = keeper.rafts[bufnr]
  return raft ~= nil and raft.buffers ~= nil and raft.buffers.python ~= nil
end

local function activate_python_lsp()
  if not is_markdown_buffer() then
    return
  end

  local bufnr = current_buffer()
  if has_python_raft(bufnr) then
    return
  end

  local activated, err = pcall(otter.activate, { "python" }, true, true)
  if not activated then
    vim.notify("Otter Python LSP setup failed: " .. err, vim.log.levels.WARN)
  end
end

local function with_python_lsp(callback)
  activate_python_lsp()
  vim.defer_fn(function()
    callback()
  end, 100)
end

local function set_markdown_keymaps()
  local bufnr = current_buffer()
  vim.keymap.set("n", "K", function()
    with_python_lsp(vim.lsp.buf.hover)
  end, { buffer = bufnr, desc = "Hover documentation", silent = true })

  vim.keymap.set("n", "gd", function()
    with_python_lsp(vim.lsp.buf.definition)
  end, { buffer = bufnr, desc = "Go to definition", silent = true })

  vim.keymap.set("i", "<C-h>", function()
    with_python_lsp(vim.lsp.buf.signature_help)
  end, { buffer = bufnr, desc = "Signature help", silent = true })
end

otter.setup({
  lsp = {
    diagnostic_update_events = { "BufWritePost" },
    root_dir = function(_, bufnr)
      return vim.fs.root(bufnr or 0, {
        ".git",
        "pyproject.toml",
        "setup.py",
        "setup.cfg",
        "requirements.txt",
      }) or vim.fn.getcwd(0)
    end,
  },
  buffers = {
    set_filetype = true,
    write_to_disk = false,
    ignore_pattern = {
      python = "^(%s*[%%!].*)",
    },
  },
  handle_leading_whitespace = true,
  verbose = {
    no_code_found = false,
  },
})

vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("dotfiles_otter_markdown", { clear = true }),
  pattern = { "markdown", "rmd" },
  callback = function()
    set_markdown_keymaps()
    vim.schedule(activate_python_lsp)
  end,
})

vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost" }, {
  group = vim.api.nvim_create_augroup("dotfiles_otter_markdown_activate", { clear = true }),
  pattern = { "*.md", "*.markdown", "*.ppmd", "*.rmd" },
  callback = function()
    vim.schedule(activate_python_lsp)
  end,
})

vim.schedule(activate_python_lsp)
