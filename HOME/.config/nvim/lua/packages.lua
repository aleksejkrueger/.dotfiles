local M = {}

local core_specs = {
  { name = 'Comment.nvim', src = 'https://github.com/numToStr/Comment.nvim.git', version = '0236521ea582747b58869cb72f70ccfa967d2e89' },
  { name = 'FixCursorHold.nvim', src = 'https://github.com/antoinemadec/FixCursorHold.nvim.git', version = '1900f89dc17c603eec29960f57c00bd9ae696495' },
  { name = 'LuaSnip', src = 'https://github.com/L3MON4D3/LuaSnip.git', version = '73813308abc2eaeff2bc0d3f2f79270c491be9d7' },
  { name = 'bufferline.nvim', src = 'https://github.com/akinsho/bufferline.nvim.git', version = '99337f63f0a3c3ab9519f3d1da7618ca4f91cffe' },
  { name = 'cmp-buffer', src = 'https://github.com/hrsh7th/cmp-buffer.git', version = '3022dbc9166796b644a841a02de8dd1cc1d311fa' },
  { name = 'cmp-cmdline', src = 'https://github.com/hrsh7th/cmp-cmdline.git', version = 'd250c63aa13ead745e3a40f61fdd3470efde3923' },
  { name = 'cmp-nvim-lsp', src = 'https://github.com/hrsh7th/cmp-nvim-lsp.git', version = 'bd5a7d6db125d4654b50eeae9f5217f24bb22fd3' },
  { name = 'cmp-path', src = 'https://github.com/hrsh7th/cmp-path.git', version = '91ff86cd9c29299a64f968ebb45846c485725f23' },
  { name = 'cmp_luasnip', src = 'https://github.com/saadparwaiz1/cmp_luasnip.git', version = '98d9cb5c2c38532bd9bdb481067b20fea8f32e90' },
  { name = 'copilot-cmp', src = 'https://github.com/zbirenbaum/copilot-cmp.git', version = '15fc12af3d0109fa76b60b5cffa1373697e261d1' },
  { name = 'copilot-lsp', src = 'https://github.com/copilotlsp-nvim/copilot-lsp.git', version = 'a80e0c17e7366614d39506825f49a25d285fead9' },
  { name = 'copilot.lua', src = 'https://github.com/zbirenbaum/copilot.lua.git', version = '92e08cd472653beaece28ad9c8508a851a613358' },
  { name = 'friendly-snippets', src = 'https://github.com/rafamadriz/friendly-snippets.git', version = '572f5660cf05f8cd8834e096d7b4c921ba18e175' },
  { name = 'gitsigns.nvim', src = 'https://github.com/lewis6991/gitsigns.nvim.git', version = '4a143f13e122ab91abdc88f89eefbe70a4858a56' },
  { name = 'impatient.nvim', src = 'https://github.com/lewis6991/impatient.nvim.git', version = '47302af74be7b79f002773011f0d8e85679a7618' },
  { name = 'indent-blankline.nvim', src = 'https://github.com/lukas-reineke/indent-blankline.nvim.git', version = 'd98f537c3492e87b6dc6c2e3f66ac517528f406f' },
  { name = 'lsp_signature.nvim', src = 'https://github.com/ray-x/lsp_signature.nvim.git', version = '62cadce83aaceed677ffe7a2d6a57141af7131ea' },
  { name = 'lspkind.nvim', src = 'https://github.com/onsails/lspkind.nvim', version = '3ddd1b4edefa425fda5a9f95a4f25578727c0bb3' },
  { name = 'lualine.nvim', src = 'https://github.com/nvim-lualine/lualine.nvim.git', version = '0a5a66803c7407767b799067986b4dc3036e1983' },
  { name = 'nui.nvim', src = 'https://github.com/MunifTanjim/nui.nvim.git', version = 'de740991c12411b663994b2860f1a4fd0937c130' },
  { name = 'nvim-autopairs', src = 'https://github.com/windwp/nvim-autopairs.git', version = 'c15de7e7981f1111642e7e53799e1211d4606cb9' },
  { name = 'nvim-cmp', src = 'https://github.com/hrsh7th/nvim-cmp.git', version = '5260e5e8ecadaf13e6b82cf867a909f54e15fd07' },
  { name = 'nvim-lspconfig', src = 'https://github.com/neovim/nvim-lspconfig.git', version = '4d38bece98300e3e5cd24a9aa0d0ebfea4951c16' },
  { name = 'nvim-tree.lua', src = 'https://github.com/nvim-tree/nvim-tree.lua.git', version = '26632f496e7e3c0450d8ecff88f49068cecc8bda' },
  { name = 'nvim-treesitter', src = 'https://github.com/nvim-treesitter/nvim-treesitter.git', version = '26171d8f105d97746371d1b6c07c8d88bf13fec2' },
  { name = 'nvim-ts-context-commentstring', src = 'https://github.com/JoosepAlviste/nvim-ts-context-commentstring.git', version = 'cb064386e667def1d241317deed9fd1b38f0dc2e' },
  { name = 'nvim-web-devicons', src = 'https://github.com/kyazdani42/nvim-web-devicons.git', version = 'b4b302d6ae229f67df7a87ef69fa79473fe788a9' },
  { name = 'obsidian.nvim', src = 'https://github.com/obsidian-nvim/obsidian.nvim', version = '20432a5ca03d99a9d5ad51d362e19d9b832e46f0' },
  { name = 'plenary.nvim', src = 'https://github.com/nvim-lua/plenary.nvim.git', version = 'a3e3bc82a3f95c5ed0d7201546d5d2c19b20d683' },
  { name = 'render-markdown.nvim', src = 'https://github.com/MeanderingProgrammer/render-markdown.nvim.git', version = 'd53856423be5ef3c267d26ee261b0981b372f718' },
  { name = 'telescope.nvim', src = 'https://github.com/nvim-telescope/telescope.nvim.git', version = 'dfa230be84a044e7f546a6c2b0a403c739732b86' },
  { name = 'vim', src = 'https://github.com/dracula/vim.git', version = '28874a1e9d583eb0b1dfebb9191445b822812ea3' },
  { name = 'vim-easymotion', src = 'https://github.com/easymotion/vim-easymotion.git', version = 'b3cfab2a6302b3b39f53d9fd2cd997e1127d7878' },
  { name = 'vim-ripgrep', src = 'https://github.com/jremmen/vim-ripgrep.git', version = '2bb2425387b449a0cd65a54ceb85e123d7a320b8' },
  { name = 'vim-slime', src = 'https://github.com/jpalardy/vim-slime.git', version = 'ca59df2570e1a12f9ddfa90b6118df4d87453fcd' },
  { name = 'vim-visual-multi', src = 'https://github.com/mg979/vim-visual-multi/', version = 'a6975e7c1ee157615bbc80fc25e4392f71c344d4' },
  { name = 'vimwiki', src = 'https://github.com/vimwiki/vimwiki.git', version = '72792615e739d0eb54a9c8f7e0a46a6e2407c9e8' },
}

local optional_specs = {
  { name = 'CopilotChat.nvim', src = 'https://github.com/CopilotC-Nvim/CopilotChat.nvim.git', version = '21bdecb25aa72119d11d7fc08c7e0ce323f1b540' },
  { name = 'avante.nvim', src = 'https://github.com/yetone/avante.nvim.git', version = 'e89eb79abf5754645e20aa6074da10ed20bba33c' },
  { name = 'bufremove', src = 'https://github.com/echasnovski/mini.bufremove', version = '66019ecebdc5bc0759e04747586994e2e3f98416' },
  { name = 'diffview.nvim', src = 'https://github.com/sindrets/diffview.nvim', version = '4516612fe98ff56ae0415a259ff6361a89419b0a' },
  { name = 'fzf', src = 'https://github.com/junegunn/fzf', version = '3b68dcdd81394f1ac9f743e1f74ff754f95eef9e' },
  { name = 'fzf.vim', src = 'https://github.com/junegunn/fzf.vim', version = '98dcd77a189a8a87052c20d1be8082aea60101b7' },
  { name = 'harpoon', src = 'https://github.com/ThePrimeagen/harpoon.git', version = 'ccae1b9bec717ae284906b0bf83d720e59d12b91' },
  { name = 'img-clip.nvim', src = 'https://github.com/hakonharnes/img-clip.nvim.git', version = 'e7e29f0d07110405adecd576b602306a7edd507a' },
  { name = 'jupytext.vim', src = 'https://github.com/goerz/jupytext.vim.git', version = 'ec8f337bd5799e16a02816d04b7c91b9555d79c2' },
  { name = 'mason-lspconfig.nvim', src = 'https://github.com/williamboman/mason-lspconfig.nvim.git', version = '8db12610bcb7ce67013cfdfaba4dd47a23c6e851' },
  { name = 'mason-null-ls.nvim', src = 'https://github.com/jay-babu/mason-null-ls.nvim.git', version = 'de19726de7260c68d94691afb057fa73d3cc53e7' },
  { name = 'mason-tool-installer.nvim', src = 'https://github.com/WhoIsSethDaniel/mason-tool-installer.nvim.git', version = 'c5e07b8ff54187716334d585db34282e46fa2932' },
  { name = 'mason.nvim', src = 'https://github.com/mason-org/mason.nvim.git', version = 'ad7146aa61dcaeb54fa900144d768f040090bff0' },
  { name = 'mcphub.nvim', src = 'https://github.com/ravitemer/mcphub.nvim.git', version = '5193329d510a68f1f5bf189960642c925c177a3a' },
  { name = 'neogit', src = 'https://github.com/NeogitOrg/neogit', version = '2a47e1df95605b232fbdd5d369ab1bfaaf40fce4' },
  { name = 'none-ls.nvim', src = 'https://github.com/nvimtools/none-ls.nvim.git', version = '8e3692eea77f4961216158e46bffd2869451d8d6' },
  { name = 'nvim-dap', src = 'https://github.com/mfussenegger/nvim-dap.git', version = '6f79b822997f2e8a789c6034e147d42bc6706770' },
  { name = 'nvim-dap-python', src = 'https://github.com/mfussenegger/nvim-dap-python.git', version = 'ae0225d0d4a46e18e6057ab3701ef87bbbd6aaad' },
  { name = 'nvim-dap-ui', src = 'https://github.com/rcarriga/nvim-dap-ui.git', version = 'b7267003ba4dd860350be86f75b9d9ea287cedca' },
  { name = 'nvim-dap-virtual-text', src = 'https://github.com/theHamsta/nvim-dap-virtual-text.git', version = 'd7c695ea39542f6da94ee4d66176f5d660ab0a77' },
  { name = 'nvim-ipy', src = 'https://github.com/bfredl/nvim-ipy.git', version = '50a938a7b24a327dd72284e11a5405875917f29b' },
  { name = 'nvim-nio', src = 'https://github.com/nvim-neotest/nvim-nio.git', version = '7969e0a8ffabdf210edd7978ec954a47a737bbcc' },
  { name = 'rnvimr', src = 'https://github.com/kevinhwang91/rnvimr.git', version = '3c41af742a61caf74a9f83fb82b9ed03ef13b880' },
  { name = 'vim-bbye', src = 'https://github.com/moll/vim-bbye.git', version = '25ef93ac5a87526111f43e5110675032dbcacf56' },
}

local function strip_config_packpath()
  local config_path = vim.fn.stdpath('config')
  local real_config_path = vim.uv.fs_realpath(config_path)
  local filtered = {}

  for _, path in ipairs(vim.split(vim.o.packpath, ',', { plain = true })) do
    local real_path = vim.uv.fs_realpath(path)
    if path ~= config_path and path ~= real_config_path and real_path ~= config_path and real_path ~= real_config_path then
      table.insert(filtered, path)
    end
  end

  vim.o.packpath = table.concat(filtered, ',')
end

local function register_pack_hooks()
  vim.api.nvim_create_autocmd('PackChanged', {
    callback = function(ev)
      local data = ev.data
      if not data or not data.spec then
        return
      end

      if data.spec.name ~= 'avante.nvim' then
        return
      end

      if data.kind ~= 'install' and data.kind ~= 'update' then
        return
      end

      vim.system({ 'make' }, { cwd = data.path }, function(result)
        vim.schedule(function()
          if result.code == 0 then
            vim.notify('Built avante.nvim native libraries', vim.log.levels.INFO)
            return
          end

          local stderr = vim.trim(result.stderr or '')
          if stderr == '' then
            stderr = 'make failed without stderr output'
          end
          vim.notify('Failed to build avante.nvim: ' .. stderr, vim.log.levels.ERROR)
        end)
      end)
    end,
  })
end

function M.bootstrap()
  strip_config_packpath()
  register_pack_hooks()

  vim.api.nvim_create_user_command('PackUpdate', function()
    vim.pack.update()
  end, { desc = 'Update native vim.pack plugins' })

  vim.pack.add(core_specs, { load = true })
  vim.pack.add(optional_specs, { load = false })
end

return M
