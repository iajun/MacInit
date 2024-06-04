vim.g.codeium_disable_bindings = true

local key_mappings = {
	["<C-y>"] = function()
		return vim.fn["codeium#Accept"]()
	end,
	["<C-h>"] = function()
		return vim.fn["codeium#CycleCompletions"](1)
	end,
	["<C-l>"] = function()
		return vim.fn["codeium#CycleCompletions"](-1)
	end,
	["<C-x>"] = function()
		return vim.fn["codeium#Clear"]()
	end,
}

for k, v in pairs(key_mappings) do
	vim.keymap.set("i", k, v, { expr = true })
end

lvim.builtin.lualine.options.theme = "catppuccin"

lvim.builtin.lualine.sections = {
	lualine_a = { "mode" },
	lualine_b = { "branch", "diff", "diagnostics" },
	lualine_c = { "filename" },
	lualine_x = {
		{
			'vim.fn["codeium#GetStatusString"]()',
			fmt = function(str)
				return "suggestions " .. str:lower():match("^%s*(.-)%s*$")
			end,
		},
		"encoding",
		"fileformat",
		"filetype",
	},
	lualine_y = { "progress" },
	lualine_z = { "location" },
}
