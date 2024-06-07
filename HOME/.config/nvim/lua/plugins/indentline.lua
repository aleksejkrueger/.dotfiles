local status_ok, ibl = pcall(require, "ibl")
if not status_ok then
  return
end

ibl.setup {
  indent = {
    char = "▏",  -- or "│", "▎" as per your preference
  },
  exclude = {
    buftypes = { "terminal", "nofile" },
    filetypes = {
      "help",
      "startify",
      "dashboard",
      "packer",
      "neogitstatus",
      "NvimTree",
      "Trouble",
      "text"
    }
  },
  scope = {
    enabled = true,  -- equivalent to g:indent_blankline_show_current_context
  },
  -- Uncomment and adjust the following if needed
  -- highlight = {
  --   char = {
  --     "IndentBlanklineIndent1",
  --     "IndentBlanklineIndent2",
  --     "IndentBlanklineIndent3",
  --     "IndentBlanklineIndent4",
  --     "IndentBlanklineIndent5",
  --     "IndentBlanklineIndent6",
  --   },
  --   -- Add more configurations if necessary
  -- },
}

-- Setting listchars and enabling list
vim.opt.list = true
vim.opt.listchars:append("space:⋅")
-- vim.opt.listchars:append("space:")  -- Alternative space character
vim.opt.listchars:append("eol:↴")

-- Custom highlight settings (uncomment if used)
-- vim.cmd [[highlight IndentBlanklineIndent1 guifg=#E06C75 gui=nocombine]]
-- vim.cmd [[highlight IndentBlanklineIndent2 guifg=#E5C07B gui=nocombine]]
-- vim.cmd [[highlight IndentBlanklineIndent3 guifg=#98C379 gui=nocombine]]
-- vim.cmd [[highlight IndentBlanklineIndent4 guifg=#56B6C2 gui=nocombine]]
-- vim.cmd [[highlight IndentBlanklineIndent5 guifg=#61AFEF gui=nocombine]]
-- vim.cmd [[highlight IndentBlanklineIndent6 guifg=#C678DD gui=nocombine]]
