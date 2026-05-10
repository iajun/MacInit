return {
  {
    "olimorris/codecompanion.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
    },
    config = function()
      require("codecompanion").setup({
        strategies = {
          chat = {
            adapter = "deepseek",
          },
          inline = {
            adapter = "deepseek",
          },
          cmd = {
            adapter = "deepseek",
          },
        },
        opts = {
          log_level = "DEBUG",
        },
        -- adapters = {
        --   deepseek = function()
        --     return require("codecompanion.adapters").extend("openai", {
        --       name = "deepseek",
        --       env = {
        --         url = "https://api.deepseek.com", -- optional: default value is ollama url http://127.0.0.1:11434
        --         api_key = "DEEPSEEK_API_KEY", -- optional: if your endpoint is authenticated
        --         chat_url = "/v1/chat/completions", -- optional: default value, override if different
        --         models_endpoint = "/v1/models", -- optional: attaches to the end of the URL to form the endpoint to retrieve models
        --       },
        --       schema = {
        --         model = {
        --           default = "deepseek-chat", -- define llm model to be used
        --         },
        --       },
        --     })
        --   end,
        -- },
      })
    end,
  },
  -- {
  --   "Exafunction/codeium.vim",
  --   config = function()
  --     -- Change '<C-g>' here to any keycode you like.
  --     vim.keymap.set("i", "<C-g>", function()
  --       return vim.fn["codeium#Accept"]()
  --     end, { expr = true, silent = true })
  --     vim.keymap.set("i", "<c-l>", function()
  --       return vim.fn["codeium#CycleCompletions"](1)
  --     end, { expr = true, silent = true })
  --     vim.keymap.set("i", "<c-h>", function()
  --       return vim.fn["codeium#CycleCompletions"](-1)
  --     end, { expr = true, silent = true })
  --     vim.keymap.set("i", "<c-x>", function()
  --       return vim.fn["codeium#Clear"]()
  --     end, { expr = true, silent = true })
  --   end,
  -- },
}
