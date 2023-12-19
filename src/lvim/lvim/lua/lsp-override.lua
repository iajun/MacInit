local formatters = require("lvim.lsp.null-ls.formatters")

formatters.setup({
	{
		name = "eslint_d",
		filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact", "vue" },
	},
})

lvim.builtin.which_key.mappings["l"]["f"] = {
  function()
    require("lvim.lsp.utils").format { timeout_ms = 2000 }
  end,
  "Format",
}
