 --       ___           ___           ___                                      ___
 --      /\  \         /\__\         /\  \          ___                       /\  \
 --      \:\  \       /:/ _/_       /::\  \        /\  \        ___          |::\  \
 --       \:\  \     /:/ /\__\     /:/\:\  \       \:\  \      /\__\         |:|:\  \
 --   _____\:\  \   /:/ /:/ _/_   /:/  \:\  \       \:\  \    /:/__/       __|:|\:\  \
 --  /::::::::\__\ /:/_/:/ /\__\ /:/__/ \:\__\  ___  \:\__\  /::\  \      /::::|_\:\__\
 --  \:\~~\~~\/__/ \:\/:/ /:/  / \:\  \ /:/  / /\  \ |:|  |  \/\:\  \__   \:\~~\  \/__/
 --   \:\  \        \::/_/:/  /   \:\  /:/  /  \:\  \|:|  |   ~~\:\/\__\   \:\  \
 --    \:\  \        \:\/:/  /     \:\/:/  /    \:\__|:|__|      \::/  /    \:\  \
 --     \:\__\        \::/  /       \::/  /      \::::/__/       /:/  /      \:\__\
 --      \/__/         \/__/         \/__/        ~~~~           \/__/        \/__/

-- Get the HOME directory
local home_dir = os.getenv("HOME")

-- basics
require "settings"
require "keymaps"
local vim_work_lua_path = home_dir .. "/.work/vim.lua"
vim.cmd("source " .. vim_work_lua_path)
-- plugins
require "plugins.cmp"
require "plugins.telescope"
require "plugins.autopairs"
require "plugins.comment"
require "plugins.lsp-inlayhints"
require "plugins.gitsigns"
require "plugins.nvim-tree"
require "plugins.bufferline"
require "plugins.lualine"
require "plugins.impatient"
require "plugins.indentline"
require "plugins.autocommands"
require "plugins.null-ls"
require "plugins.dap"
require "plugins.mason"
require "plugins.vimwiki"
require "plugins.iron"
