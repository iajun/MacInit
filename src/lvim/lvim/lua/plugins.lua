lvim.plugins = {
  {
    "tpope/vim-surround",
    "mg979/vim-visual-multi",
    {
      "windwp/nvim-ts-autotag",
      after = "nvim-treesitter",
      requires = "nvim-treesitter/nvim-treesitter",
    },
    "arcticicestudio/nord-vim",
    {
      "phaazon/hop.nvim",
      branch = 'v2',
      event = "BufRead",
    },
    {
      "nvim-treesitter/nvim-treesitter-textobjects",
      after = "nvim-treesitter",
      requires = "nvim-treesitter/nvim-treesitter",
    },
    {
      'Exafunction/codeium.vim',
      config = function()
        -- Change '<C-g>' here to any keycode you like.
        vim.keymap.set('i', '<C-y>', function() return vim.fn['codeium#Accept']() end, { expr = true })
        vim.keymap.set('i', '<C-h>', function() return vim.fn['codeium#CycleCompletions'](1) end, { expr = true })
        vim.keymap.set('i', '<C-l>', function() return vim.fn['codeium#CycleCompletions'](-1) end, { expr = true })
        vim.keymap.set('i', '<c-x>', function() return vim.fn['codeium#Clear']() end, { expr = true })
      end
    },
    {
      "kelly-lin/telescope-ag",
      dependencies = { "nvim-telescope/telescope.nvim" },
    },
    {
      "nvim-telescope/telescope-frecency.nvim",
      config = function()
        require "telescope".load_extension("frecency")
      end,
      dependencies = { "kkharji/sqlite.lua" }
    },
  },
  {
    "jay-babu/mason-null-ls.nvim",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "williamboman/mason.nvim",
      "jose-elias-alvarez/null-ls.nvim",
    },
  },
  "tpope/vim-fugitive",
}
