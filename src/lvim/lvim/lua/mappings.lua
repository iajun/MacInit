-- Define Which Key mappings
local which_key_mappings = {}

-- Define normal mode key mappings
local normal_mode_mappings = {
	["<leader>b\\"] = ":vs<CR>",
	["<leader>b-"] = ":split<CR>",
	["<leader>oo"] = ":cd %:p:h<CR>:pwd<CR>",
}

for k, v in pairs(which_key_mappings) do
	lvim.builtin.which_key.mappings[k] = v
end

for k, v in pairs(normal_mode_mappings) do
	lvim.keys.normal_mode[k] = v
end
