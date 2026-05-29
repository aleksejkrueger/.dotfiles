local M = {}

local defaults = {
    tmux_target = "1",
    cell_header = "# %%",
}

local markdown_filetypes = {
    markdown = true,
    mkd = true,
    rmd = true,
}

local function is_markdown_buffer()
    return markdown_filetypes[vim.bo.filetype] == true
end

local function tmux_buffer_name(suffix)
    local pane = vim.env.TMUX_PANE or "nvim"

    return ("nvim_tunnel_%s_%s"):format(pane:gsub("[^%w_%-]", "_"), suffix)
end

local function tmux_system(args, input)
    if vim.fn.executable("tmux") ~= 1 then
        print("tmux is not executable.")
        return false, ""
    end

    local output = vim.fn.system(args, input)

    if vim.v.shell_error ~= 0 then
        print(vim.trim(output))
        return false, output
    end

    return true, output
end

local function tmux_pane_option(name)
    if not vim.env.TMUX or not vim.env.TMUX_PANE then
        return nil
    end

    local ok, output = tmux_system({
        "tmux",
        "display-message",
        "-p",
        "-t",
        vim.env.TMUX_PANE,
        "#{"
            .. name
            .. "}",
    })

    if not ok then
        return nil
    end

    output = vim.trim(output)

    if output == "" then
        return nil
    end

    return output
end

local function context_command()
    return tmux_pane_option("@nvim_context_command")
end

local function target_pane()
    if vim.b.tmux_target and vim.b.tmux_target ~= "" then
        return vim.b.tmux_target
    end

    return tmux_pane_option("@nvim_repl_pane") or defaults.tmux_target
end

local function paste_text(target, text, suffix)
    local buffer_name = tmux_buffer_name(suffix)
    local ok = tmux_system({ "tmux", "load-buffer", "-b", buffer_name, "-" }, text)

    if not ok then
        return false
    end

    ok = tmux_system({ "tmux", "paste-buffer", "-dpr", "-b", buffer_name, "-t", target })

    return ok
end

local function send_enter(target)
    local ok = tmux_system({ "tmux", "send-keys", "-t", target, "Enter" })

    return ok
end

local function python_snapshot_source(vars_file)
    local source = ([[
def __nvim_tmux_vars_snapshot(__nvim_tmux_vars_path):
    import datetime as __datetime
    import inspect as __inspect
    import types as __types
    import json as __json
    import os as __os

    def __short_text(__value, __limit=120):
        try:
            __text = repr(__value)
        except Exception as __error:
            __text = "<repr failed: " + type(__error).__name__ + ">"
        __text = " ".join(str(__text).split())
        if len(__text) > __limit:
            return __text[:__limit - 1] + "."
        return __text

    def __detail_text(__value):
        __shape = getattr(__value, "shape", None)
        if __shape is not None:
            return "shape=" + repr(__shape)
        try:
            return "len=" + str(len(__value))
        except Exception:
            return ""

    __excluded_names = {"In", "Out", "exit", "quit", "get_ipython"}
    __excluded_prefixes = ("__nvim", "_nvim", "_dh", "_i", "_ih", "_ii", "_iii", "_oh", "_sh")
    __items = []

    for __name, __value in sorted(globals().items()):
        if __name in __excluded_names or __name.startswith("_"):
            continue
        if __name.startswith(__excluded_prefixes):
            continue
        if (
            isinstance(__value, __types.ModuleType)
            or __inspect.isfunction(__value)
            or __inspect.ismethod(__value)
            or __inspect.isbuiltin(__value)
        ):
            continue
        __items.append({
            "name": __name,
            "type": type(__value).__name__,
            "detail": __detail_text(__value),
            "value": __short_text(__value),
        })

    __payload = {
        "updated_at": __datetime.datetime.now().strftime("%%H:%%M:%%S"),
        "vars": __items,
    }
    __tmp_path = __nvim_tmux_vars_path + ".tmp"

    with open(__tmp_path, "w", encoding="utf-8") as __handle:
        __json.dump(__payload, __handle)

    __os.replace(__tmp_path, __nvim_tmux_vars_path)

__nvim_tmux_vars_snapshot(%s)
del __nvim_tmux_vars_snapshot
]]):format(vim.fn.json_encode(vars_file))

    return "exec(" .. vim.fn.json_encode(source) .. ")"
end

local function r_snapshot_source(vars_file)
    local hook_path = vim.fn.expand("~/.dotfiles/src/repl-vars-hook.R")
    local source = ([[
Sys.setenv(NVIM_TMUX_VARS_FILE = %s, NVIM_TMUX_R_HOOK_FILE = %s)
if (!nzchar(Sys.getenv("NVIM_TMUX_R_PROFILE_USER", ""))) {
  Sys.setenv(NVIM_TMUX_R_PROFILE_USER = "__nvim_tmux_no_profile__")
}
if (!exists(".nvim_tmux_write_vars_snapshot", envir = .GlobalEnv, mode = "function") && file.exists(%s)) {
  source(%s, local = .GlobalEnv)
}
if (exists(".nvim_tmux_write_vars_snapshot", envir = .GlobalEnv, mode = "function")) {
  .nvim_tmux_write_vars_snapshot()
}
]]):format(
        vim.fn.json_encode(vars_file),
        vim.fn.json_encode(hook_path),
        vim.fn.json_encode(hook_path),
        vim.fn.json_encode(hook_path)
    )

    return source
end

local function is_python_context()
    local extension = vim.fn.expand("%:e"):lower()

    return context_command() == "ipython"
        or vim.bo.filetype == "python"
        or extension == "py"
        or extension == "ipy"
        or extension == "ipynb"
end

local function is_r_context()
    local extension = vim.fn.expand("%:e"):lower()

    return context_command() == "R"
        or vim.bo.filetype == "r"
        or vim.bo.filetype == "rmd"
        or extension == "r"
        or extension == "rmd"
end

local function refresh_repl_vars(target)
    local vars_file = tmux_pane_option("@nvim_vars_file")

    if not vars_file then
        return
    end

    local source = nil
    if is_r_context() then
        source = r_snapshot_source(vars_file)
    elseif is_python_context() then
        source = python_snapshot_source(vars_file)
    end

    if source and paste_text(target, source, "vars") then
        send_enter(target)
    end
end

local function parse_fence(line)
    local marker, info = line:match("^%s*(```+)%s*(.*)$")

    if marker then
        return {
            char = "`",
            length = #marker,
            info = vim.trim(info or ""),
        }
    end

    marker, info = line:match("^%s*(~~~+)%s*(.*)$")

    if marker then
        return {
            char = "~",
            length = #marker,
            info = vim.trim(info or ""),
        }
    end

    return nil
end

local function is_closing_fence(line, opening_fence)
    local fence = parse_fence(line)

    return fence ~= nil and fence.char == opening_fence.char and fence.length >= opening_fence.length
end

local function is_python_cell_info(info)
    local normalized = info:lower()

    return normalized:match("^python[%s,}]") ~= nil
        or normalized == "python"
        or normalized:match("^py[%s,}]") ~= nil
        or normalized == "py"
        or normalized:match("^ipython") ~= nil
        or normalized:match("^%{python[%s,}]") ~= nil
        or normalized:match("^%{code%-cell") ~= nil
end

local function is_r_cell_info(info)
    local normalized = info:lower()

    return normalized == "r"
        or normalized:match("^r[%s,}]") ~= nil
        or normalized:match("^%{r[%s,}]") ~= nil
end

local function is_current_cell_info(info)
    if is_r_context() then
        return is_r_cell_info(info)
    end

    if is_python_context() then
        return is_python_cell_info(info)
    end

    return is_python_cell_info(info) or is_r_cell_info(info)
end

local function markdown_code_cell_range()
    local cursor_line = vim.fn.line(".")
    local opening_line = nil
    local opening_fence = nil

    for line_number = 1, cursor_line do
        local line = vim.fn.getline(line_number)

        if opening_fence then
            if is_closing_fence(line, opening_fence) then
                opening_line = nil
                opening_fence = nil
            end
        else
            local fence = parse_fence(line)

            if fence then
                opening_line = line_number
                opening_fence = fence
            end
        end
    end

    if not opening_line or not opening_fence or not is_current_cell_info(opening_fence.info) then
        return nil
    end

    for line_number = opening_line + 1, vim.fn.line("$") do
        if is_closing_fence(vim.fn.getline(line_number), opening_fence) then
            return {
                line1 = opening_line + 1,
                line2 = line_number - 1,
            }
        end
    end

    return {
        line1 = opening_line + 1,
        line2 = vim.fn.line("$"),
    }
end

-- Sets buffer-variables `cell_header` and `tmux_target` to values given by user via `vim.fn.input`
local function config()
    -- cell_header
    vim.b.cell_header = vim.fn.input({
        prompt = "Cell header: ",
        -- autocomplete with current cell header if exists, otherwise autocomplete with global
        default = vim.b.cell_header and vim.b.cell_header or defaults.cell_header,
    })

    -- tmux_target
    vim.b.tmux_target = vim.fn.input({
        prompt = "Tmux target pane: ",
        -- autocomplete with current target if exists, otherwise autocomplete with global
        default = vim.b.tmux_target and vim.b.tmux_target or target_pane(),
    })
end

-- Tunnells range `r` to target
--
-- Reads `r.line1` and `r.line2`
local function tunnell_range(r)
    if r.line1 > r.line2 then
        print("Empty cell.")
        return
    end

    local lines = vim.api.nvim_buf_get_lines(0, r.line1 - 1, r.line2, false)
    local target = target_pane()

    if paste_text(target, table.concat(lines, "\n"), "code") then
        send_enter(target)
    end
end

-- Tunnells cell to target
--
-- Cursor does not have to be on the cell header, but anywhere inside the cell
local function tunnell_cell()
    if is_markdown_buffer() then
        local range = markdown_code_cell_range()

        if range then
            tunnell_range(range)
            vim.fn.search("^\\s*\\(```\\|~~~\\)", "W")
            return
        end
    end

    -- load cell_header
    local cell_header = vim.b.cell_header and vim.b.cell_header or defaults.cell_header

    -- define start of cell
    -- 'b'  search Backward instead of forward
    -- 'c'  accept a match at the Cursor position
    -- 'n'  do Not move the cursor
    -- 'W'  don't Wrap around the end of the file
    local start_line = vim.fn.search(cell_header, "bcnW")

    -- if no header is found above cursor, do nothing
    if start_line == 0 then
        print("No cell header found above cursor!")
        return
    end

    -- define end of cell
    local end_line = vim.fn.search(cell_header, "nW")

    -- if no header found below cursor, cursor is in the last cell so end line should be the
    -- last line of the file. Otherwise, end line is one line above next cell header
    if end_line == 0 then
        end_line = vim.fn.line("$")
    else
        end_line = end_line - 1
    end

    -- tunnell cell range
    tunnell_range({ line1 = start_line, line2 = end_line })

    -- put cursor on next cell
    vim.cmd("silent /" .. cell_header)
end

-- create user commands
vim.api.nvim_create_user_command("TunnellConfig", config, {})
vim.api.nvim_create_user_command("TunnellLine", function()
    local line = vim.fn.line(".")

    tunnell_range({ line1 = line, line2 = line })
end, {})
vim.api.nvim_create_user_command("TunnellRange", tunnell_range, { range = true })
vim.api.nvim_create_user_command("TunnellCell", tunnell_cell, {})
vim.api.nvim_create_user_command("TunnellVars", function()
    refresh_repl_vars(target_pane())
end, {})

-- Setup function for users to call from their plugin managers
function M.setup(user_config)
    -- merge user-config with defaults
    defaults = vim.tbl_deep_extend("force", defaults, user_config or {})
end

return M
