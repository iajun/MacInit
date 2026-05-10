return {
  {
    "terryma/vim-multiple-cursors",
  },
  {
    "tpope/vim-surround",
  },
  {
    "JoosepAlviste/nvim-ts-context-commentstring",
  },
  {
    "antosha417/nvim-lsp-file-operations",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-neo-tree/neo-tree.nvim",
    },
    config = function()
      require("lsp-file-operations").setup()
    end,
  },
}
