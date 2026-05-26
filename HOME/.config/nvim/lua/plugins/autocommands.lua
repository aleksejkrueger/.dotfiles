-- vim.api.nvim_create_autocmd({ "User" }, {
--   pattern = { "AlphaReady" },
--   callback = function()
--     vim.cmd [[
--       set showtabline=0 | autocmd BufUnload <buffer> set showtabline=2
--     ]]
--   end,
-- })

vim.api.nvim_create_autocmd({ "User" }, {
  pattern = { "AlphaReady" },
  callback = function()
    vim.cmd [[
      set laststatus=0 | autocmd BufUnload <buffer> set laststatus=3
    ]]
  end,
})

vim.api.nvim_create_autocmd({ "FileType" }, {
  pattern = {
    "Jaq",
    "qf",
    "help",
    "man",
    "lspinfo",
    "spectre_panel",
    "lir",
    "DressingSelect",
    "tsplayground",
    "Markdown",
  },
  callback = function()
    vim.cmd [[
      nnoremap <silent> <buffer> q :close<CR> 
      nnoremap <silent> <buffer> <esc> :close<CR> 
      set nobuflisted 
    ]]
  end,
})

vim.api.nvim_create_autocmd({ "FileType" }, {
  pattern = { "Jaq" },
  callback = function()
    vim.cmd [[
      nnoremap <silent> <buffer> <m-r> :close<CR>
      " nnoremap <silent> <buffer> <m-r> <NOP> 
      set nobuflisted 
    ]]
  end,
})

vim.api.nvim_create_autocmd({ "BufEnter" }, {
  pattern = { "" },
  callback = function()
    local buf_ft = vim.bo.filetype
    if buf_ft == "" or buf_ft == nil then
      vim.cmd [[
      nnoremap <silent> <buffer> q :close<CR> 
      nnoremap <silent> <buffer> <c-j> j<CR> 
      nnoremap <silent> <buffer> <c-k> k<CR> 
      set nobuflisted 
    ]]
    end
  end,
})

vim.api.nvim_create_autocmd({ "BufEnter" }, {
  pattern = { "" },
  callback = function()
    local get_project_dir = function()
      local cwd = vim.fn.getcwd()
      local project_dir = vim.split(cwd, "/")
      local project_name = project_dir[#project_dir]
      return project_name
    end

    vim.opt.titlestring = get_project_dir() .. " - nvim"
  end,
})

vim.api.nvim_create_autocmd({ "BufEnter" }, {
  pattern = { "term://*" },
  callback = function()
    vim.cmd "startinsert!"
    -- TODO: if java = 2
    vim.cmd "set cmdheight=1"
  end,
})

vim.api.nvim_create_autocmd({ "FileType" }, {
  pattern = { "gitcommit", "markdown" },
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.spell = true
  end,
})

local function set_tmux_pane_option(name, value)
  if not vim.env.TMUX or not vim.env.TMUX_PANE or vim.fn.executable("tmux") ~= 1 then
    return
  end

  local args = { "tmux", "set-option", "-p", "-t", vim.env.TMUX_PANE }

  if value and value ~= "" then
    vim.list_extend(args, { name, value })
  else
    vim.list_extend(args, { "-u", name })
  end

  vim.fn.jobstart(args, { detach = true })
end

local repl_by_extension = {
  ipynb = "ipython",
  ipy = "ipython",
  py = "ipython",
  pyi = "ipython",
  pyw = "ipython",
  r = "R",
  rmd = "R",
  lua = "lua",
}

local repl_by_filetype = {
  python = "ipython",
  r = "R",
  lua = "lua",
}

local function repl_command_for_buffer(path)
  local extension = vim.fn.fnamemodify(path, ":e"):lower()

  return repl_by_extension[extension] or repl_by_filetype[vim.bo.filetype]
end

local function clear_tmux_context()
  set_tmux_pane_option("@nvim_context_dir", nil)
  set_tmux_pane_option("@nvim_context_command", nil)
  set_tmux_pane_option("@nvim_ipynb_dir", nil)
end

local function sync_tmux_context()
  local path = vim.api.nvim_buf_get_name(0)
  local command = path ~= "" and repl_command_for_buffer(path) or nil

  if path == "" or not command then
    clear_tmux_context()
    return
  end

  local directory = vim.fn.fnamemodify(path, ":p:h")

  set_tmux_pane_option("@nvim_context_dir", directory)
  set_tmux_pane_option("@nvim_context_command", command)

  if vim.fn.fnamemodify(path, ":e"):lower() == "ipynb" then
    set_tmux_pane_option("@nvim_ipynb_dir", directory)
  else
    set_tmux_pane_option("@nvim_ipynb_dir", nil)
  end
end

vim.api.nvim_create_autocmd({ "BufEnter", "BufFilePost", "FileType" }, {
  callback = sync_tmux_context,
})

vim.api.nvim_create_autocmd({ "VimLeavePre" }, {
  callback = clear_tmux_context,
})

vim.api.nvim_create_autocmd({ "FileType" }, {
  pattern = { "lir" },
  callback = function()
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
  end,
})

vim.cmd "autocmd BufEnter * ++nested if winnr('$') == 1 && bufname() == 'NvimTree_' . tabpagenr() | quit | endif"
-- vim.api.nvim_create_autocmd({ "BufEnter" }, {
--   callback = function()
--     vim.cmd [[
--       if winnr('$') == 1 && bufname() == 'NvimTree_' . tabpagenr() | quit | endif
--     ]]
--   end,
-- })

vim.api.nvim_create_autocmd({ "VimResized" }, {
  callback = function()
    vim.cmd "tabdo wincmd ="
  end,
})

vim.api.nvim_create_autocmd({ "CmdWinEnter" }, {
  callback = function()
    vim.cmd "quit"
  end,
})

vim.api.nvim_create_autocmd({ "BufWinEnter" }, {
  callback = function()
    vim.cmd "set formatoptions-=cro"
  end,
})

vim.api.nvim_create_autocmd({ "TextYankPost" }, {
  callback = function()
    vim.highlight.on_yank { higroup = "Visual", timeout = 200 }
  end,
})

vim.api.nvim_create_autocmd({ "BufWritePost" }, {
  pattern = { "*.java" },
  callback = function()
    vim.lsp.codelens.refresh()
  end,
})

vim.api.nvim_create_autocmd({ "VimEnter" }, {
  callback = function()
    vim.cmd "hi link illuminatedWord LspReferenceText"
  end,
})

vim.api.nvim_create_autocmd({ "BufWinEnter" }, {
  pattern = { "*" },
  callback = function()
    vim.cmd "checktime"
  end,
})

vim.api.nvim_create_autocmd({ "CursorHold" }, {
  callback = function()
    local status_ok, luasnip = pcall(require, "luasnip")
    if not status_ok then
      return
    end
    if luasnip.expand_or_jumpable() then
      -- ask maintainer for option to make this silent
      -- luasnip.unlink_current()
      vim.cmd [[silent! lua require("luasnip").unlink_current()]]
    end
  end,
})

-- vim.api.nvim_create_autocmd({ "ModeChanged" }, {
--   callback = function()
--     local luasnip = require "luasnip"
--     if luasnip.expand_or_jumpable() then
--       -- ask maintainer for option to make this silent
--       -- luasnip.unlink_current()
--       vim.cmd [[silent! lua require("luasnip").unlink_current()]]
--     end
--   end,
-- })

vim.api.nvim_create_autocmd({ "BufWritePost" }, {
  pattern = { "*.ts" },
  callback = function()
    vim.lsp.buf.format { async = true }
  end,
})
