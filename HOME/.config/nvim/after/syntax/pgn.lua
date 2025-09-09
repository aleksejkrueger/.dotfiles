-- PGN syntax highlighting (Lua, Neovim)

-- clear if already set
if vim.b.current_syntax then
  return
end

vim.cmd("syntax clear")

vim.cmd("syntax case ignore")

-- ****************
-- *** Comments ***
-- ****************
vim.cmd([[syntax match pgnComment "^\s*%.*"]])
vim.cmd([[syntax match pgnComment ";.*"]])
vim.cmd([[syntax region pgnComment start=/{/ end=/}/]])

-- ****************
-- *** Strings ***
-- ****************
vim.cmd([[syntax region pgnString start=/"/ skip=/\\\\\|\\"/ end=/"/ contained oneline]])

-- ****************
-- *** Tags ***
-- ****************
vim.cmd([[syntax region pgnTag start=/^\s*\[/ end=/\]\s*$/ contains=pgnString oneline]])

-- ****************
-- *** Move numbers ***
-- ****************
vim.cmd([[syntax match pgnMoveNumber "[1-9][0-9]*\.\(\.\.\)\="]])

-- ****************
-- *** Game result ***
-- ****************
vim.cmd([[syntax match pgnResult "\*\|0-1\|1-0\|1\/2-1\/2"]])

-- ****************
-- *** Highlight groups ***
-- ****************
local function link(group, target)
  vim.api.nvim_set_hl(0, group, { link = target })
end

link("pgnComment", "Comment")
link("pgnString", "String")
link("pgnTag", "Keyword")
link("pgnMoveNumber", "Number")
link("pgnResult", "Type")

vim.b.current_syntax = "pgn"
