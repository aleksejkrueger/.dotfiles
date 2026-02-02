-- search for multiple tags with :Rg. order doesnt matter
vim.api.nvim_create_user_command('Rgtags', function(opts)
  if #opts.fargs == 0 then
    print("usage: :Rgtags tag1 tag2 ...")
    return
  end

  -- base regex: any line
  local regex = "^"

    for _, tag in ipairs(opts.fargs) do
        -- ensure there exists a tag containing the substring
        regex = regex .. "(?=.*:([^:]*" .. tag .. "[^:]*):)"
    end

  regex = regex .. ".*$"

  local cmd = "Rg --pcre2 '" .. regex .. "'"
  vim.cmd(cmd)
end, { nargs = '+' })


-- example usage :Rgtags tag1 tag2 
