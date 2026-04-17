-- Direct setup for Obsidian.nvim without Lazy.nvim
require("obsidian").setup({
  legacy_commands = false, -- this will be removed in the next major release
  workspaces = {
    {
      name = "notes",
      path = "~/notes/vimwiki",
    },
  },
  templates = {
    folder = "Templates",
    date_format = "%Y-%m-%d",
    time_format = "%H:%M",
  },
  ui = {
    enable = false,
  },
})
