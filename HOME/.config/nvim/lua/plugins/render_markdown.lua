local render_markdown = require('render-markdown')
local render_markdown_manager = require('render-markdown.core.manager')

render_markdown.setup({
  file_types = { 'markdown', 'rmd', 'Avante' },
  overrides = {
    filetype = {
      markdown = { enabled = false },
      rmd = { enabled = false },
    },
  },
})

local markdown_filetypes = {
  markdown = true,
  rmd = true,
}

local markdown_filetype_by_extension = {
  markdown = 'markdown',
  md = 'markdown',
  ppmd = 'markdown',
  rmd = 'rmd',
}

local function markdown_filetype_for_path(path)
  local extension = vim.fn.fnamemodify(path, ':e'):lower()

  return markdown_filetype_by_extension[extension]
end

local function is_markdown_buffer()
  return markdown_filetypes[vim.bo.filetype] == true
end

local function ensure_markdown_buffer()
  if is_markdown_buffer() then
    return true
  end

  local filetype = markdown_filetype_for_path(vim.api.nvim_buf_get_name(0))

  if not filetype then
    return false
  end

  vim.bo.filetype = filetype
  return true
end

local function with_markdown_buffer(callback)
  if not ensure_markdown_buffer() then
    vim.notify('Markdown rendering is only configured for Markdown buffers', vim.log.levels.WARN)
    return
  end

  local buffer = vim.api.nvim_get_current_buf()

  vim.schedule(function()
    render_markdown_manager.attach(buffer)
    callback(buffer)
  end)
end

vim.api.nvim_create_user_command('MarkdownRenderEnable', function()
  with_markdown_buffer(function(buffer)
    render_markdown_manager.set_buf(buffer, true)
  end)
end, { desc = 'Enable render-markdown for the current Markdown buffer' })

vim.api.nvim_create_user_command('MarkdownRenderDisable', function()
  with_markdown_buffer(function(buffer)
    render_markdown_manager.set_buf(buffer, false)
  end)
end, { desc = 'Disable render-markdown for the current Markdown buffer' })

vim.api.nvim_create_user_command('MarkdownRenderToggle', function()
  with_markdown_buffer(function(buffer)
    render_markdown_manager.set_buf(buffer)
  end)
end, { desc = 'Toggle render-markdown for the current Markdown buffer' })

vim.keymap.set('n', '<leader>mr', function()
  with_markdown_buffer(function(buffer)
    render_markdown_manager.set_buf(buffer)
  end)
end, {
  desc = 'Toggle Markdown rendering',
  silent = true,
})
