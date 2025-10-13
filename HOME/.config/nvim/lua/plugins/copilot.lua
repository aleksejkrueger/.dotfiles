-- Optional: define key mappings
local keys = {
  { "<leader>zc", ":CopilotChat<CR>", mode = "n", desc = "Chat with Copilot" },
  { "<leader>ze", ":CopilotChatExplain<CR>", mode = "v", desc = "Explain Code" },
  { "<leader>zr", ":CopilotChatReview<CR>", mode = "v", desc = "Review Code" },
  { "<leader>zf", ":CopilotChatFix<CR>", mode = "v", desc = "Fix Code Issues" },
  { "<leader>zo", ":CopilotChatOptimize<CR>", mode = "v", desc = "Optimize Code" },
  { "<leader>zd", ":CopilotChatDocs<CR>", mode = "v", desc = "Generate Docs" },
  { "<leader>zt", ":CopilotChatTests<CR>", mode = "v", desc = "Generate Tests" },
  { "<leader>zm", ":CopilotChatCommit<CR>", mode = "n", desc = "Generate Commit Message" },
  { "<leader>zs", ":CopilotChatCommit<CR>", mode = "v", desc = "Generate Commit for Selection" },
}



-- Register key mappings (if not handled by plugin)
for _, map in ipairs(keys) do
  vim.keymap.set(map.mode, map[1], map[2], { desc = map.desc })
end

require("copilot_cmp").setup()


require('copilot').setup({
  panel = {
    enabled = false,
    auto_refresh = true,
    keymap = {
      jump_prev = "[[",
      jump_next = "]]",
      accept = "<CR>",
      refresh = "gr",
      open = "<M-CR>"
    },
    layout = {
      position = "bottom",
      ratio = 0.4
    },
  },
  suggestion = {
    enabled = false,
    auto_trigger = true,
    hide_during_completion = true,
    debounce = 75,
    trigger_on_accept = true,
    keymap = {
      accept = "<M-l>",
      accept_word = false,
      accept_line = false,
      next = "<M-]>",
      prev = "<M-[>",
      dismiss = "<C-]>",
    },
  },
  nls = { 
    enabled = true, -- requires copilot-lsp as a dependency
    auto_trigger = true,
    keymap = {
      accept_and_goto = false,
      accept = false,
      dismiss = false,
    },
  },
  auth_provider_url = "https://dkbag.ghe.com", -- URL to authentication provider
  logger = {
    file = vim.fn.stdpath("log") .. "/copilot-lua.log",
    file_log_level = vim.log.levels.OFF,
    print_log_level = vim.log.levels.WARN,
    trace_lsp = "off",
    trace_lsp_progress = false,
    log_lsp_messages = false,
  },
  copilot_node_command = 'node',
  workspace_folders = {},
  copilot_model = "",
  disable_limit_reached_message = false,
  root_dir = function()
    return vim.fs.dirname(vim.fs.find(".git", { upward = true })[1])
  end,
  should_attach = function(_, _)
    if not vim.bo.buflisted then
      return false -- FIXED: removed logger.debug
    end

    if vim.bo.buftype ~= "" then
      return false -- FIXED: removed logger.debug
    end

    return true
  end,
  server = {
    type = "nodejs",
    custom_server_filepath = nil,
  },
  server_opts_overrides = {},
})

require("CopilotChat").setup({
  debug = false,
  context = "buffers",
  window = {
    layout = "vertical",
    width = 0.4,
    height = 0.6,
    border = "rounded",
  },
  github_instance_url = "dkbag.ghe.com",
  github_instance_api_url = "dkbag.ghe.com/api/v3",
  mappings = {
    complete = {
      insert = "<C-Space>",
    },
    close = {
      normal = "q",
    },
  },
})

vim.g.copilot_enterprise_url = 'https://dkbag.ghe.com'
vim.g.copilot_auth_provider_url = 'https://dkbag.ghe.com'

