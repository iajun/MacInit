local formatters = require("lvim.lsp.null-ls.formatters")
formatters.setup({
	{
		name = "prettierd",
		filetypes = { "typescript", "typescriptreact", "vue", "json", "javascript", "javascriptreact" },
	},
	{
		name = "beautysh",
		filetypes = { "bash", "sh", "zsh" },
	},
	{
		name = "eslint_d",
		filetypes = {
			"typescript",
			"typescriptreact",
			"vue",
			"json",
			"javascript",
			"javascriptreact",
			"yaml",
			"css",
			"less",
		},
	},
	{
		name = "stylua",
		filetypes = { "lua" },
	},
})
