lvim.plugins = {
  {
    "tpope/vim-surround",
    "mg979/vim-visual-multi",
    {
      "windwp/nvim-ts-autotag",
      after = "nvim-treesitter",
      requires = "nvim-treesitter/nvim-treesitter",
    },
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
    },

    -- theme
    { "catppuccin/nvim", name = "catppuccin", priority = 1000 },

    -- telescope
    "nvim-telescope/telescope-project.nvim",
    "nvim-telescope/telescope-dap.nvim",
    "nvim-telescope/telescope-frecency.nvim",
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
