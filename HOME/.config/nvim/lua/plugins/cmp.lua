local cmp_status_ok, cmp = pcall(require, "cmp")
if not cmp_status_ok then
  return
end

local snip_status_ok, luasnip = pcall(require, "luasnip")
if not snip_status_ok then
  return
end

-- snippet loaders
require("luasnip.loaders.from_snipmate").lazy_load()
require("luasnip.loaders.from_vscode").lazy_load()

-- basic settings
vim.opt.completeopt = { "menu", "menuone", "noselect" }

local sig_status_ok, lsp_signature = pcall(require, "lsp_signature")
if sig_status_ok then
        lsp_signature.setup({
          bind = true,
          doc_lines = 0,
          floating_window = true,
          floating_window_above_cur_line = true,
          hint_enable = false,
          hint_prefix = "  ",
          hint_scheme = "Comment",
          hi_parameter = "LspSignatureActiveParameter",
          max_height = 20,
          max_width = 120,
          wrap = true,
          handler_opts = {
            border = "rounded", -- use rounded for a clean cmp-style look
          },
          transparency = 100,
          toggle_key = "<M-x>",
          zindex = 60, -- ensure it's above cmp window
          padding = " ",
          timer_interval = 200,
          always_trigger = false,
          auto_close_after = nil,
          extra_trigger_chars = { "(", "," },
          fix_pos = false,
          floating_window_off_x = 0, -- fine-tune horizontal offset if needed
          floating_window_off_y = 0,
          select_signature_key = "<M-n>",
          move_cursor_key = "<M-m>",
          close_timeout = 4000,
        })

        -- highlight tuning for dracula-like theme
        vim.api.nvim_set_hl(0, "LspSignatureActiveParameter", {
          fg = "#ff79c6",
          bg = "none",
          bold = true,
        })

        vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })
        vim.api.nvim_set_hl(0, "FloatBorder", { fg = "#6272a4", bg = "none" })
end


-- helper functions
local has_words_before = function()
  if vim.api.nvim_buf_get_option(0, "buftype") == "prompt" then return false end
  local line, col = unpack(vim.api.nvim_win_get_cursor(0))
  return col ~= 0 and vim.api.nvim_buf_get_text(0, line-1, 0, line-1, col, {})[1]:match("^%s*$") == nil
end

local check_backspace = function() 
  local col = vim.fn.col(".") - 1
  return col == 0 or vim.fn.getline("."):sub(col, col):match("%s")
end

-- lspkind setup
local lspkind = require("lspkind")
lspkind.init()

-- icons fallback
local kind_icons = {
  Text = "", Method = "m", Function = "", Constructor = "", Field = "",
  Variable = "", Class = "", Interface = "", Module = "", Property = "",
  Unit = "", Value = "", Enum = "", Keyword = "", Snippet = "",
  Color = "", File = "", Reference = "", Folder = "", EnumMember = "",
  Constant = "", Struct = "", Event = "", Operator = "", TypeParameter = "",
}

-- main cmp setup
cmp.setup({
  snippet = {
    expand = function(args)
      luasnip.lsp_expand(args.body)
    end,
  },
  mapping = {
    ["<C-k>"] = cmp.mapping.select_prev_item(),
    ["<C-j>"] = cmp.mapping.select_next_item(),
    ["<C-b>"] = cmp.mapping.scroll_docs(-1),
    ["<C-f>"] = cmp.mapping.scroll_docs(1),
    ["<C-Space>"] = cmp.mapping.complete(),
    ["<C-y>"] = cmp.config.disable,
    ["<C-e>"] = cmp.mapping {
      i = cmp.mapping.abort(),
      c = cmp.mapping.close(),
    },
    ["<CR>"] = cmp.mapping.confirm { select = true },
    ["<Tab>"] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_next_item()
      elseif luasnip.expandable() then
        luasnip.expand()
      elseif luasnip.expand_or_jumpable() then
        luasnip.expand_or_jump()
      elseif has_words_before() then
        cmp.complete()
      else
        fallback()
      end
    end, { "i", "s" }),
    ["<S-Tab>"] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_prev_item()
      elseif luasnip.jumpable(-1) then
        luasnip.jump(-1)
      else
        fallback()
      end
    end, { "i", "s" }),
  },
  formatting = {
    fields = { "kind", "abbr", "menu" },
    format = function(entry, vim_item)
      -- use lspkind symbol if available, fallback to kind_icons
      vim_item.kind = lspkind.symbolic(vim_item.kind, entry.source.name) or kind_icons[vim_item.kind] or vim_item.kind
      vim_item.menu = ({
        nvim_lsp = "[LSP]",
        luasnip = "[Snippet]",
        buffer = "[Buffer]",
        path = "[Path]",
      })[entry.source.name]
      return vim_item
    end,
  },
  sources = cmp.config.sources({
    { name = "nvim_lsp" },
    { name = "luasnip" },
    { name = "buffer" },
    { name = "path" },
  }),
  confirm_opts = { behavior = cmp.ConfirmBehavior.Replace, select = false },
  window = {
    completion = cmp.config.window.bordered(),
    documentation = cmp.config.window.bordered(),
  },
  experimental = { ghost_text = false, native_menu = false },
})
