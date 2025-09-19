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

-- Plugin setup
require("CopilotChat").setup({
  debug = false, -- enable verbose logs if needed
  context = "buffers", -- context passed to Copilot

  window = {
    layout = "vertical", -- 'horizontal' or 'float' also supported
    width = 0.4,
    height = 0.6,
    border = "rounded",
  },

  -- GitHub Enterprise configuration
  github_instance_url = "dkbag.ghe.com", -- without https://
  github_instance_api_url = "dkbag.ghe.com/api/v3", -- without https://

  mappings = {
    complete = {
      insert = "<C-Space>", -- trigger completion in insert mode
    },
    close = {
      normal = "q", -- close chat window
    },
  },
})

-- Optional: global variables for other plugins or fallback logic
vim.g.copilot_enterprise_url = 'https://dkbag.ghe.com'
vim.g.copilot_auth_provider_url = 'https://dkbag.ghe.com'

