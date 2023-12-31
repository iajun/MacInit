local formatters = require "lvim.lsp.null-ls.formatters"
local linters = require "lvim.lsp.null-ls.linters"
-- local actions = require "lvim.lsp.null-ls.code_actions"

-- actions.setup({
--   name = "eslint_d"
-- })

formatters.setup {
  {
    name = "prettierd",
    filetypes = { "typescript", "typescriptreact", "vue", "json", "javascript", "javascriptreact", "yaml", "css", "less",
      "scss", "html", "graphql" },
  },
  {
    name = "beautysh",
    filetypes = { "bash", "sh", "zsh" },
  }
}

linters.setup {
  {
    name = "eslint_d",
    filter = function(diagnostic)
      return diagnostic.code ~= "prettier/prettier"
    end,
  },
}

require('mason-null-ls').setup({
  automatic_installation = true,
})
