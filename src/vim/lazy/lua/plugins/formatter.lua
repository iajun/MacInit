return {
  {
    "nvim-lspconfig",
    opts = {
      setup = {
        volar = function()
          require("lazyvim.util").lsp.on_attach(function(client, _)
            if client.name == "volar" then
              client.server_capabilities.documentFormattingProvider = false
            end
          end)
        end,
      },
    },
  },
}
