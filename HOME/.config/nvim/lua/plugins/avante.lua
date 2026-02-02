require('render-markdown').setup({
  file_types = { 'markdown', 'Avante' },
})

require('avante').setup({
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
        model = "gpt-4.1-2025-04-14",
        extra_request_body = {
          temperature = 0.1,
          max_tokens = 4096,
        },
      },
    },
    -- dual_boost = {
    --   enabled = false,
    --   first_provider = "copilot",
    --   prompt = "based on the two reference outputs below, generate a response that incorporates elements from both but reflects your own judgment and unique perspective. do not provide any explanation, just give the response directly. reference output 1: [{{provider1_output}}], reference output 2: [{{provider2_output}}]",
    --   timeout = 60000,
    -- },

    behaviour = {
    auto_approve_tool_permissions = false,
    auto_focus_sidebar = true,
    auto_suggestions = false, -- Experimental stage
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
        --- @alias avante.SelectorProvider "native" | "fzf_lua" | "mini_pick" | "snacks" | "telescope" | fun(selector: avante.ui.Selector): nil
        --- @type avante.SelectorProvider
        provider = "telescope",
        -- Options override for custom providers
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
})

