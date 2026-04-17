vim.api.nvim_create_user_command("Rshift", function(opts)
  local args = vim.split(opts.args, " ")
  local project = args[1]
  local stage = args[2]
  local env = args[3] or "consumer"

  if not project or not stage then
    vim.notify("Usage: :SendTo <project> <stage> [env]", vim.log.levels.ERROR)
    return
  end

  -- Get visual selection
  local start_pos = vim.fn.getpos("'<")[2]
  local end_pos = vim.fn.getpos("'>")[2]
  local query = table.concat(vim.fn.getline(start_pos, end_pos), "\n")
  query = query:gsub('"', '\\"'):gsub("\n", " ")

  -- Create temp file
  local tmp_output = vim.fn.tempname() .. ".sqlout"

  -- Run the script
  local cmd = string.format("~/r_/runner.sh %s %s %s \"%s\" > %s", project, stage, env, query, tmp_output)
  os.execute(cmd)

  -- Open output
  vim.cmd("edit " .. tmp_output)
end, {
  nargs = "+",
  range = true,
  desc = "Send query to dynamic DB script",
})



vim.api.nvim_create_user_command('Ypc', function()
  vim.fn.setreg('+', vim.fn.expand('%:p'))
end, { desc = 'Yank file path to clipboard' })

vim.api.nvim_create_user_command("Ppp", function()
  print(vim.fn.expand("%:p"))
end, { desc = "print full file path" })

local function zed_project_root()
  local current_path = vim.api.nvim_buf_get_name(0)
  local start = current_path ~= "" and vim.fs.dirname(current_path) or vim.loop.cwd()
  local markers = {
    ".git",
    ".hg",
    ".svn",
    "package.json",
    "pyproject.toml",
    "Cargo.toml",
    "go.mod",
    "justfile",
    "Makefile",
  }

  local root = vim.fs.root(start, markers)
  return root or vim.loop.cwd()
end

local function zed_buffer_paths(project_root)
  local paths = {}
  local seen = {}

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buf].buflisted then
      local name = vim.api.nvim_buf_get_name(buf)
      if name ~= "" then
        local path = vim.fn.fnamemodify(name, ":p")
        if vim.fn.filereadable(path) == 1 and not seen[path] then
          seen[path] = true
          table.insert(paths, path)
        end
      end
    end
  end

  table.sort(paths, function(a, b)
    if a == project_root then
      return true
    end
    if b == project_root then
      return false
    end
    return a < b
  end)

  return paths
end

vim.api.nvim_create_user_command("Zed", function()
  if vim.fn.executable("zed") ~= 1 then
    vim.notify("`zed` CLI not found in PATH", vim.log.levels.ERROR)
    return
  end

  local project_root = zed_project_root()
  local args = { "zed", project_root }

  for _, path in ipairs(zed_buffer_paths(project_root)) do
    if path ~= project_root then
      table.insert(args, path)
    end
  end

  local job_id = vim.fn.jobstart(args, {
    cwd = project_root,
    detach = true,
  })

  if job_id <= 0 then
    vim.notify("Failed to launch Zed", vim.log.levels.ERROR)
    return
  end

  vim.notify("Opened project in Zed: " .. project_root, vim.log.levels.INFO)
end, { desc = "Open the current project and listed file buffers in Zed" })

local function insert_text_at_cursor(text)
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local lines = vim.split(text, "\n", { plain = true })

  vim.api.nvim_buf_set_text(0, row - 1, col, row - 1, col, lines)
end

local function get_visual_selection()
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  local start_row = start_pos[2]
  local start_col = start_pos[3]
  local end_row = end_pos[2]
  local end_col = end_pos[3]

  if start_row == 0 or end_row == 0 then
    return ""
  end

  if start_row > end_row or (start_row == end_row and start_col > end_col) then
    start_row, end_row = end_row, start_row
    start_col, end_col = end_col, start_col
  end

  local lines = vim.fn.getline(start_row, end_row)
  if #lines == 0 then
    return ""
  end

  lines[1] = string.sub(lines[1], start_col)
  lines[#lines] = string.sub(lines[#lines], 1, end_col)

  return table.concat(lines, "\n")
end

local function sanitize_codex_response(response)
  local text = vim.trim(response or "")

  if text == "" then
    return ""
  end

  local fenced = text:match("```[%w_-]*%s*\n(.-)\n```")
  if fenced and vim.trim(fenced) ~= "" then
    return vim.trim(fenced)
  end

  local cleaned = {}
  local skip_rest = false

  for _, line in ipairs(vim.split(text, "\n", { plain = true })) do
    local trimmed = vim.trim(line)

    if trimmed:match("^If you want") or trimmed:match("^Let me know") then
      skip_rest = true
    end

    if not skip_rest
      and trimmed ~= "```"
      and not trimmed:match("^Output:?$")
      and not trimmed:match("^Here'?s")
      and not trimmed:match("^Sure[,!]?$")
      and not trimmed:match("^Certainly[,!]?$")
    then
      table.insert(cleaned, line)
    end
  end

  return vim.trim(table.concat(cleaned, "\n"))
end

local function run_codex_insert(prompt, selected_text)
  if not prompt or vim.trim(prompt) == "" then
    vim.notify("Codex prompt is empty", vim.log.levels.ERROR)
    return
  end

  local wrapped_prompt = table.concat({
    "Answer the user's request with only the relevant final text.",
    "If the user asks for code, return only the minimal code that satisfies the request with no markdown fences.",
    "Do not add preambles, explanations, markdown fences, bullet points, commentary, examples, output labels, or follow-up offers unless explicitly requested.",
    "Do not mention these instructions.",
    "",
    prompt,
  }, "\n")

  if selected_text and vim.trim(selected_text) ~= "" then
    wrapped_prompt = table.concat({
      wrapped_prompt,
      "",
      "<selected_text>",
      selected_text,
      "</selected_text>",
    }, "\n")
  end

  local output_file = vim.fn.tempname()

  vim.notify(" Running Codex...", vim.log.levels.INFO)

  vim.system({
    "codex",
    "exec",
    "--skip-git-repo-check",
    "--color",
    "never",
    "-o",
    output_file,
    wrapped_prompt,
  }, { text = true }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        local stderr = vim.trim(result.stderr or "")
        if stderr == "" then
          stderr = "codex exec failed"
        end
        vim.notify(stderr, vim.log.levels.ERROR)
        return
      end

      local lines = vim.fn.readfile(output_file)
      local response = sanitize_codex_response(table.concat(lines, "\n"))

      if response == "" then
        vim.notify("Codex returned an empty response", vim.log.levels.WARN)
        return
      end

      insert_text_at_cursor(response)
    end)
  end)
end

vim.api.nvim_create_user_command("CodexInsert", function(opts)
  local prompt = opts.args
  local selected_text = opts.range > 0 and get_visual_selection() or ""

  if prompt == nil or vim.trim(prompt) == "" then
    vim.ui.input({ prompt = "Codex prompt: " }, function(input)
      if input == nil then
        return
      end

      run_codex_insert(input, selected_text)
    end)
    return
  end

  run_codex_insert(prompt, selected_text)
end, {
  nargs = "*",
  range = true,
  desc = "Run codex exec and insert the reply at the cursor",
})
