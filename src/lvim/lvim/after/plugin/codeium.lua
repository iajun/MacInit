local key_mappings = {
  ["<C-y>"] = function() return vim.fn['codeium#Accept']() end,
  ["<C-h>"] = function() return vim.fn['codeium#CycleCompletions'](1) end,
  ["<C-l>"] = function() return vim.fn['codeium#CycleCompletions'](-1) end,
  ["<C-x>"] = function() return vim.fn['codeium#Clear']() end,
}

for k, v in pairs(key_mappings) do
  vim.keymap.set("i", k, v, { expr = true })
end
