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

