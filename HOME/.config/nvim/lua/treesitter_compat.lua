local M = {}

local unpack = unpack or table.unpack

local info_string_aliases = {
  ex = "elixir",
  pl = "perl",
  sh = "bash",
  ts = "typescript",
  uxn = "uxntal",
}

local html_script_type_languages = {
  ["application/ecmascript"] = "javascript",
  ["importmap"] = "json",
  ["module"] = "javascript",
  ["text/ecmascript"] = "javascript",
}

local function contains(values, value)
  for _, candidate in ipairs(values) do
    if candidate == value then
      return true
    end
  end
  return false
end

local function capture_nodes(match, capture_id)
  local nodes = {}

  local function collect(value)
    if type(value) == "userdata" then
      nodes[#nodes + 1] = value
    elseif type(value) == "table" then
      for _, item in ipairs(value) do
        collect(item)
      end
    end
  end

  collect(match[capture_id])
  return nodes
end

local function first_capture_node(match, capture_id)
  return capture_nodes(match, capture_id)[1]
end

local function parser_from_info_string(alias)
  local filetype = vim.filetype.match({ filename = "a." .. alias })
  return filetype or info_string_aliases[alias] or alias
end

local function patch_query_predicates_for_nvim_012()
  if vim.fn.has("nvim-0.12") == 0 then
    return
  end

  local ok, query = pcall(require, "vim.treesitter.query")
  if not ok then
    return
  end

  -- Load nvim-treesitter's legacy handlers first, then replace the ones that
  -- still assume captures are single TSNode values instead of TSNode lists.
  pcall(require, "nvim-treesitter.query_predicates")

  query.add_predicate("nth?", function(match, _, _, pred)
    local nodes = capture_nodes(match, pred[2])
    local child_index = tonumber(pred[3])
    if not child_index then
      return false
    end

    for _, node in ipairs(nodes) do
      local parent = node:parent()
      if parent and parent:named_child_count() > child_index and parent:named_child(child_index) == node then
        return true
      end
    end

    return false
  end, { force = true })

  local function has_ancestor(match, _, _, pred)
    local nodes = capture_nodes(match, pred[2])
    if #nodes == 0 then
      return true
    end

    local ancestor_types = { unpack(pred, 3) }
    local direct_parent_only = pred[1]:find("has-parent", 1, true) ~= nil

    for _, node in ipairs(nodes) do
      local parent = node:parent()
      while parent do
        if contains(ancestor_types, parent:type()) then
          return true
        end
        parent = direct_parent_only and nil or parent:parent()
      end
    end

    return false
  end

  query.add_predicate("has-ancestor?", has_ancestor, { force = true })
  query.add_predicate("has-parent?", has_ancestor, { force = true })

  query.add_predicate("is?", function(match, _, source, pred)
    local nodes = capture_nodes(match, pred[2])
    if #nodes == 0 then
      return true
    end

    local locals_ok, locals = pcall(require, "nvim-treesitter.locals")
    if not locals_ok then
      return false
    end

    local kinds = { unpack(pred, 3) }
    for _, node in ipairs(nodes) do
      local _, _, kind = locals.find_definition(node, source)
      if contains(kinds, kind) then
        return true
      end
    end

    return false
  end, { force = true })

  query.add_predicate("kind-eq?", function(match, _, _, pred)
    local nodes = capture_nodes(match, pred[2])
    if #nodes == 0 then
      return true
    end

    local types = { unpack(pred, 3) }
    for _, node in ipairs(nodes) do
      if contains(types, node:type()) then
        return true
      end
    end

    return false
  end, { force = true })

  query.add_directive("set-lang-from-mimetype!", function(match, _, source, pred, metadata)
    local node = first_capture_node(match, pred[2])
    if not node then
      return
    end

    local mimetype = vim.treesitter.get_node_text(node, source)
    local parts = vim.split(mimetype, "/", { plain = true })
    metadata["injection.language"] = html_script_type_languages[mimetype] or parts[#parts]
  end, { force = true })

  query.add_directive("set-lang-from-info-string!", function(match, _, source, pred, metadata)
    local node = first_capture_node(match, pred[2])
    if not node then
      return
    end

    local alias = vim.treesitter.get_node_text(node, source):lower()
    metadata["injection.language"] = parser_from_info_string(alias)
  end, { force = true })

  query.add_directive("make-range!", function() end, { force = true })

  query.add_directive("downcase!", function(match, _, source, pred, metadata)
    local capture_id = pred[2]
    local node = first_capture_node(match, capture_id)
    if not node then
      return
    end

    metadata[capture_id] = metadata[capture_id] or {}
    local text = vim.treesitter.get_node_text(node, source, { metadata = metadata[capture_id] }) or ""
    metadata[capture_id].text = text:lower()
  end, { force = true })

  query.add_directive("trim!", function(match, _, source, pred, metadata)
    for _, capture_id in ipairs({ select(2, unpack(pred)) }) do
      local node = first_capture_node(match, capture_id)
      if node then
        local trim_start_lines = pred[3] == "1"
        local trim_start_cols = pred[4] == "1"
        local trim_end_lines = pred[5] == "1" or not pred[3]
        local trim_end_cols = pred[6] == "1"
        local start_row, start_col, end_row, end_col = node:range()
        local node_text = vim.split(vim.treesitter.get_node_text(node, source), "\n")

        if end_col == 0 then
          node_text[#node_text + 1] = ""
        end

        local end_idx = #node_text
        local start_idx = 1

        if trim_end_lines then
          while end_idx > 0 and node_text[end_idx]:find("^%s*$") do
            end_idx = end_idx - 1
            end_row = end_row - 1
            end_col = end_idx > 0 and #node_text[end_idx] or 0
          end
        end

        if trim_end_cols then
          if end_idx == 0 then
            end_row = start_row
            end_col = start_col
          else
            local whitespace_start = node_text[end_idx]:find("(%s*)$")
            end_col = (whitespace_start - 1) + (end_idx == 1 and start_col or 0)
          end
        end

        if trim_start_lines then
          while start_idx <= end_idx and node_text[start_idx]:find("^%s*$") do
            start_idx = start_idx + 1
            start_row = start_row + 1
            start_col = 0
          end
        end

        if trim_start_cols and node_text[start_idx] then
          local _, whitespace_end = node_text[start_idx]:find("^(%s*)")
          start_col = (start_idx == 1 and start_col or 0) + (whitespace_end or 0)
        end

        if start_row < end_row or (start_row == end_row and start_col <= end_col) then
          metadata[capture_id] = metadata[capture_id] or {}
          metadata[capture_id].range = { start_row, start_col, end_row, end_col }
        end
      end
    end
  end, { force = true })
end

local function patch_python_except_star_query()
  local ok, info = pcall(vim.treesitter.language.inspect, "python")
  if not ok or not info.symbols or info.symbols['"except*"'] ~= nil then
    return
  end

  local query_ok, query_err = pcall(vim.treesitter.query.get, "python", "highlights")
  if query_ok or not tostring(query_err):find('Invalid node type "except*"', 1, true) then
    return
  end

  local files = vim.treesitter.query.get_files("python", "highlights")
  local chunks = {}
  for _, file in ipairs(files) do
    local handle = io.open(file, "r")
    if handle then
      chunks[#chunks + 1] = handle:read("*a")
      handle:close()
    end
  end

  if #chunks == 0 then
    return
  end

  local query = table.concat(chunks, ""):gsub('[^\n]*"except%*"[^\n]*\n', "")
  vim.treesitter.query.set("python", "highlights", query)
end

function M.setup()
  patch_query_predicates_for_nvim_012()
  patch_python_except_star_query()
end

return M
