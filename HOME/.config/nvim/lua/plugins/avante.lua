local function patch_treesitter_directives_for_nvim_012()
  if vim.fn.has('nvim-0.12') == 0 then
    return
  end

  local ok, query = pcall(require, 'vim.treesitter.query')
  if not ok then
    return
  end

  pcall(require, 'nvim-treesitter.query_predicates')

  local function get_first_node(captures, capture_id)
    local capture = captures[capture_id]
    if type(capture) == 'table' then
      return capture[1]
    end
    return capture
  end

  local function get_parser_from_markdown_info_string(injection_alias)
    local match = vim.filetype.match({ filename = 'a.' .. injection_alias })
    local aliases = {
      ex = 'elixir',
      pl = 'perl',
      sh = 'bash',
      ts = 'typescript',
      uxn = 'uxntal',
    }
    return match or aliases[injection_alias] or injection_alias
  end

  -- nvim-treesitter revisions pinned before Neovim 0.12 still assume a
  -- single TSNode here. Neovim 0.12 now passes a list of captures.
  query.add_directive('set-lang-from-info-string!', function(match, _, bufnr, pred, metadata)
    local node = get_first_node(match, pred[2])
    if not node then
      return
    end
    local injection_alias = vim.treesitter.get_node_text(node, bufnr):lower()
    metadata['injection.language'] = get_parser_from_markdown_info_string(injection_alias)
  end, true)
end

patch_treesitter_directives_for_nvim_012()

require('render-markdown').setup({
  file_types = { 'markdown', 'Avante' },
})

local avante_config = {
  ---@alias Provider "copilot"
  ---@type Provider
  provider = "copilot",

  ---@alias Mode "agentic" | "legacy"
  ---@type Mode
  mode = "legacy",
  auto_suggestions_provider = "copilot",
  providers = {
    copilot = {
      endpoint = "https://dkbag.ghe.com",
      model = "gpt-5-mini",
      extra_request_body = {
        temperature = 0.1,
        max_tokens = 4096,
      },
    },
  },
  behaviour = {
    auto_approve_tool_permissions = false,
    auto_focus_sidebar = true,
    auto_suggestions = false,
    auto_suggestions_respect_ignore = true,
    auto_set_highlight_group = true,
    auto_set_keymaps = true,
    auto_apply_diff_after_generation = true,
    jump_result_buffer_on_finish = false,
    support_paste_from_clipboard = false,
    minimize_diff = true,
    enable_token_counting = true,
    use_cwd_as_project_root = false,
    auto_focus_on_diff_view = false,
  },
  selector = {
    provider = "telescope",
    provider_opts = {},
  },
  prompt_logger = {
    enabled = true,
    log_dir = vim.fn.stdpath("cache") .. "/avante_prompts",
    fortune_cookie_on_success = false,
    next_prompt = {
      normal = "<C-n>",
      insert = "<C-n>",
    },
    prev_prompt = {
      normal = "<C-p>",
      insert = "<C-p>",
    },
  },
  mappings = {
    diff = {
      ours = "co",
      theirs = "ct",
      all_theirs = "ca",
      both = "cb",
      cursor = "cc",
      next = "]x",
      prev = "[x",
    },
    suggestion = {
      accept = "<M-l>",
      next = "<M-]>",
      prev = "<M-[>",
      dismiss = "<C-]>",
    },
    jump = {
      next = "]]",
      prev = "[[",
    },
    submit = {
      normal = "<CR>",
      insert = "<C-s>",
    },
    cancel = {
      normal = { "<C-c>", "<Esc>", "q" },
      insert = { "<C-c>" },
    },
    sidebar = {
      apply_all = "A",
      apply_cursor = "a",
      retry_user_request = "r",
      edit_user_request = "e",
      switch_windows = "<Tab>",
      reverse_switch_windows = "<S-Tab>",
      remove_file = "d",
      add_file = "@",
      close = { "<Esc>", "q" },
      close_from_input = nil,
    },
  },
  selection = {
    enabled = true,
    hint_display = "delayed",
  },
  windows = {
    position = "right",
    wrap = true,
    width = 30,
    sidebar_header = {
      enabled = true,
      align = "center",
      rounded = true,
    },
    spinner = {
      editing = { "⡀", "⠄", "⠂", "⠁", "⠈", "⠐", "⠠", "⢀", "⣀", "⢄", "⢂", "⢁", "⢈", "⢐", "⢠", "⣠", "⢤", "⢢", "⢡", "⢨", "⢰", "⣰", "⢴", "⢲", "⢱", "⢸", "⣸", "⢼", "⢺", "⢹", "⣹", "⢽", "⢻", "⣻", "⢿", "⣿" },
      generating = { "·", "✢", "✳", "∗", "✻", "✽" },
      thinking = { "🤯", "🙄" },
    },
    input = {
      prefix = "> ",
      height = 8,
    },
    edit = {
      border = "rounded",
      start_insert = true,
    },
    ask = {
      floating = false,
      start_insert = true,
      border = "rounded",
      focus_on_apply = "ours",
    },
  },
  highlights = {
    diff = {
      current = "DiffText",
      incoming = "DiffAdd",
    },
  },
  diff = {
    autojump = true,
    list_opener = "copen",
    override_timeoutlen = 500,
  },
  suggestion = {
    debounce = 600,
    throttle = 600,
  },
}

local function setup_avante()
  local ok, avante = pcall(require, 'avante')
  if not ok then
    vim.schedule(function()
      vim.notify("Avante not available", vim.log.levels.WARN)
    end)
    return
  end

  local configured, err = pcall(avante.setup, avante_config)
  if not configured then
    vim.schedule(function()
      vim.notify("Avante setup skipped: " .. err, vim.log.levels.WARN)
    end)
  end
end

vim.api.nvim_create_user_command('AvanteRetrySetup', setup_avante, { desc = 'Retry Avante setup' })
setup_avante()
