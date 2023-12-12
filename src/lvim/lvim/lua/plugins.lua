lvim.plugins = {
	{
		"tpope/vim-surround",
		"mg979/vim-visual-multi",
		{
			"windwp/nvim-ts-autotag",
			after = "nvim-treesitter",
			requires = "nvim-treesitter/nvim-treesitter",
			config = function()
				require("nvim-treesitter.configs").setup({
					autotag = {
						enable = true,
						enable_rename = true,
						enable_close = true,
						enable_close_on_slash = true,
						filetypes = { "html", "xml", "typescriptreact", "javascriptreact", "vue" },
					},
				})
			end,
		},
		{
			"phaazon/hop.nvim",
			branch = "v2",
			event = "BufRead",
		},
		{
			"nvim-treesitter/nvim-treesitter-textobjects",
			after = "nvim-treesitter",
			requires = "nvim-treesitter/nvim-treesitter",
		},

		-- ai
		{
			"Exafunction/codeium.vim",
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

	-- git
	"lewis6991/gitsigns.nvim",

	-- debug
	"jay-babu/mason-nvim-dap.nvim",

	-- markdown
	{
		"iamcco/markdown-preview.nvim",
		cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
		ft = { "markdown" },
		build = function()
			vim.fn["mkdp#util#install"]()
		end,
	},

	-- others
	{
		"skywind3000/asyncrun.vim",
	},
}
