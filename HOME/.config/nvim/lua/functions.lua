--- Scans the current buffer for potential file paths and Python module names.
--- 
--- Extracts file-like tokens and Python-style module references (e.g., `a.b.c` → `a/b/c.py`).
--- Validates whether each resolved path exists, de-duplicates the results, and shows
--- them in an FZF picker with `bat` preview. Selecting an entry opens the file in the editor.
---
--- Useful for quickly jumping to files referenced in code, logs, or documentation.
---
--- Note: You must run this command from the project root directory for correct path resolution.
--- Paths are resolved relative to the current working directory.
vim.api.nvim_create_user_command("Paths", function()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local paths = {}
  local seen = {}

  local function add_if_valid(path)
    local expanded = vim.fn.expand(path)
    if vim.fn.filereadable(expanded) == 1 then
      local relpath = vim.fn.fnamemodify(expanded, ":.")
      if not seen[relpath] then
        table.insert(paths, relpath)
        seen[relpath] = true
      end
    end
  end

  for _, line in ipairs(lines) do
    -- Detect file-like tokens
    for token in line:gmatch("[^%s%p]*[/%w%.%_%-%~%$]+[^%s%p]*") do
      add_if_valid(token)
    end

    -- Python module style: a.b.c → a/b/c.py
    for mod in line:gmatch("([%w_]+[%w_%.]+)") do
      if mod:find("%.") then
        local py_path = mod:gsub("%.", "/") .. ".py"
        add_if_valid(py_path)
      end
    end
  end

  if #paths == 0 then
    print("No valid paths or module files found.")
    return
  end

  vim.fn["fzf#run"](vim.fn["fzf#wrap"]({
    source = paths,
    options = "--preview 'bat --style=numbers --color=always {}' --preview-window=right:70%",
    sink = function(sel) vim.cmd("edit " .. vim.fn.fnameescape(sel)) end,
  }))
end, {})


