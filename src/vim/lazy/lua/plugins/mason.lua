return {
  {
    "williamboman/mason.nvim",
    opts = {
      -- Don't add jdtls (Java) to this as that is installed and managed by the nvim-java plugin
      -- These are the ones that are not supported in mason-lspconfig.
      ensure_installed = {
        "markdownlint",
        "prettierd",
      },
    },
  },
  {
    "williamboman/mason-lspconfig.nvim",
    opts = {
      -- Don't add jdtls (Java) to this as that is installed and managed by the nvim-java plugin
      ensure_installed = {
        "bashls",
        "cssls",
        "eslint",
        "html",
        "jsonls",
        "marksman",
        "tsserver",
        "volar",
      },
    },
  },
  {
    "nvim-lspconfig",
    opts = {
      setup = {
        tsserver = function(_, opts)
          local mason_registry = require("mason-registry")
          local vue_language_server_path = mason_registry.get_package("vue-language-server"):get_install_path()
            .. "/node_modules/@vue/language-server"

          opts.init_options = {
            plugins = {
              {
                name = "@vue/typescript-plugin",
                location = vue_language_server_path,
                languages = { "vue" },
              },
            },
          }
          opts.filetypes = { "typescript", "javascript", "javascriptreact", "typescriptreact", "vue" }
        end,
        eslint = function()
          require("lazyvim.util").lsp.on_attach(function(client)
            if client.name == "eslint" then
              client.server_capabilities.documentFormattingProvider = true
            elseif client.name == "tsserver" then
              client.server_capabilities.documentFormattingProvider = false
            end
          end)
        end,
      },
    },
  },
}
