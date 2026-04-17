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
vim.g.skip_ts_context_commentstring_module = true

require("packages").bootstrap()

-- basics
require "settings"
require "keymaps"
require "functions"
local vim_work_lua_path = home_dir .. "/.work/vim.lua"
vim.cmd("source " .. vim_work_lua_path)
-- plugins
require "plugins.cmp"
require "plugins.obsidian"
require "plugins.telescope"
require "plugins.lspsaga"
require "plugins.autopairs"
require "plugins.comment"
require "plugins.copilot"
require "plugins.avante"
require "plugins.gitsigns"
require "plugins.nvim-tree"
require "plugins.bufferline"
require "plugins.lualine"
require "plugins.impatient"
require "plugins.indentline"
require "plugins.autocommands"
require "plugins.none-ls"
require "plugins.dap"
require "plugins.mason"
require "plugins.vimwiki"
require "plugins.tunnel"
require "plugins.mcphub"
