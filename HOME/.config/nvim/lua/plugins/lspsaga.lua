local status_ok, saga = pcall(require, "lspsaga")
if not status_ok then
  return
end

saga.setup({
  hover = {
    max_width = 0.6,
    max_height = 0.4,
  },
  symbol_in_winbar = {
    enable = true, -- show code context at top
    separator = " > ", -- customize separator
    hide_keyword = true, -- hide function/class keywords
    show_file = true, -- show filename
    folder_level = 1, -- show 2 parent folders
    color_mode = true, -- use highlight groups
  },
})

-- Keymap for hover doc (overrides K)
vim.keymap.set("n", "K", "<cmd>Lspsaga hover_doc<CR>", { noremap = true, silent = true })

-- Set background color for Lspsaga winbar context
vim.api.nvim_set_hl(0, "WinBar", { bg = "#282a36", fg = "#f8f8f2" })
