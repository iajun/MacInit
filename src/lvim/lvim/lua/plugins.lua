lvim.plugins = {
  {
    "tpope/vim-surround",
    "mg979/vim-visual-multi",
    "arcticicestudio/nord-vim",
    {
      "windwp/nvim-ts-autotag",
      ft = { "html", "xml", "typescriptreact", "javascriptreact", "vue" },
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
    "zbirenbaum/copilot.lua",
    {
      "zbirenbaum/copilot-cmp",
      after = { "copilot.lua" },
    },
    {
      "jackMort/ChatGPT.nvim",
      event = "VeryLazy",
      config = function()
        require("chatgpt").setup()
      end,
      dependencies = {
        "MunifTanjim/nui.nvim",
        "nvim-lua/plenary.nvim",
        "nvim-telescope/telescope.nvim"
      }
    }
  },
  {
    "jay-babu/mason-null-ls.nvim",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "williamboman/mason.nvim",
      "jose-elias-alvarez/null-ls.nvim",
    },
  }
}
