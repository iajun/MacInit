local formatters = require("lvim.lsp.null-ls.formatters")

formatters.setup({
	{
		name = "eslint_d",
		filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact", "vue" },
	},
})
