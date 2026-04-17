local status_ok, lualine = pcall(require, "lualine")
if not status_ok then
  return
end

local theme_ok, dracula_theme = pcall(require, "lualine.themes.dracula")
if theme_ok then
  for _, mode in pairs(dracula_theme) do
    for _, section in pairs(mode) do
      if type(section) == "table" then
        section.bg = "NONE"
      end
    end

    if type(mode.a) == "table" then
      mode.a.fg = "#f8f8f2"
    end
  end
end

---------------------------------------------------------------------
-- Custom truncated full filepath component
---------------------------------------------------------------------
local function truncated_filepath(max_parts)
  local path = vim.fn.expand("%:p")

  if path == "" then
    return ""
  end

  -- replace home with ~
  path = vim.fn.fnamemodify(path, ":~")

  local sep = package.config:sub(1, 1)
  local parts = vim.split(path, sep, { plain = true })

  if #parts <= max_parts then
    return path
  end

  local tail = { unpack(parts, #parts - max_parts + 1, #parts) }
  return "…" .. sep .. table.concat(tail, sep)
end

---------------------------------------------------------------------
-- Dynamic path component (adjusts to window width)
---------------------------------------------------------------------
local function filepath_component()
  local width = vim.api.nvim_win_get_width(0)

  -- tweak these numbers to your taste
  local depth
  if width > 160 then
    depth = 7
  elseif width > 120 then
    depth = 5
  else
    depth = 3
  end

  local name = truncated_filepath(depth)

  -- modified indicator
  if vim.bo.modified then
    name = name .. " ●"
  end

  return name
end

---------------------------------------------------------------------
-- Lualine setup
---------------------------------------------------------------------
lualine.setup {
  options = {
    icons_enabled = true,
    theme = theme_ok and dracula_theme or "dracula",
    component_separators = { left = "", right = "" },
    section_separators = { left = "", right = "" },
    disabled_filetypes = {},
    always_divide_middle = true,
    globalstatus = false,
  },

  sections = {
    lualine_a = { "mode" },

    lualine_b = {
      { "branch", icon = "" },
      "diff",
      "diagnostics",
    },

    lualine_c = {
      filepath_component,
    },

    lualine_x = {
      "encoding",
      "fileformat",
      "filetype",
      { "filesize", icon = "" },
      { "gitsigns.head", icon = "" },
      { "gitsigns.status", icon = "" },
    },

    lualine_y = { "progress" },
    lualine_z = { "location" },
  },

  inactive_sections = {
    lualine_a = {},
    lualine_b = {},
    lualine_c = {
      filepath_component,
    },
    lualine_x = { "location" },
    lualine_y = {},
    lualine_z = {},
  },

  tabline = {},
  extensions = {},
}
