local status_ok, comment = pcall(require, "Comment")
if not status_ok then
  return
end

local ts_comment_ok, ts_context_commentstring = pcall(require, "ts_context_commentstring")
local ts_integration_ok, ts_integration = pcall(require, "ts_context_commentstring.integrations.comment_nvim")
local ts_pre_hook = nil

if ts_comment_ok then
  ts_context_commentstring.setup {
    enable_autocmd = false,
  }
end

if ts_integration_ok then
  ts_pre_hook = ts_integration.create_pre_hook()
end

local status_ok_1, _ = pcall(require, "lsp-inlayhints")
if not status_ok_1 then
  return
end

comment.setup {
  ignore = "^$",
  pre_hook = function(ctx)
    -- For inlay hints
    local line_start = (ctx.srow or ctx.range.srow) - 1
    local line_end = ctx.erow or ctx.range.erow
    require("lsp-inlayhints.core").clear(0, line_start, line_end)

    if not ts_pre_hook then
      return
    end

    local ok, commentstring = pcall(ts_pre_hook, ctx)
    if ok then
      return commentstring
    end
  end,
}
---------------------------------------------------------------------------
-- how to use                                                             -
---------------------------------------------------------------------------

local ft = require('Comment.ft')

-- 1. using set function
-- just set only line comment
--ft.set('yaml', '#%s')

-- or set both line and block commentstring
-- you can also chain the set calls
--ft.set('javascript', {'//%s', '/*%s*/'}).set('conf', '#%s')

-- 2. metatable magic

-- one filetype at a time
--ft.javascript = {'//%s', '/*%s*/'}
--ft.yaml = '#%s'

-- multiple filetypes
--ft({'go', 'rust'}, {'//%s', '/*%s*/'})
--ft({'toml', 'graphql'}, '#%s')

-- 3. get the whole set of commentstring
--ft.lang('lua') -- { '--%s', '--[[%s]]' }
--ft.lang('javascript') -- { '//%s', '/*%s*/' }


-- set right comment for .Rmd & .md
ft.set('mkd', '<!--%s-->')
ft.set('rmd', '<!--%s-->')
ft.set('vimwiki', '<!--%s-->')
