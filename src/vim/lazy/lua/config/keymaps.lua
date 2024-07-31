-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local map = LazyVim.safe_keymap_set

local KeyMap = {
  x = {
    j = { "<cmd>lua vim.diagnostic.goto_next()<CR>", "Next", mode = "n" },
    k = { "<cmd>lua vim.diagnostic.goto_prev()<CR>", "Prev", mode = "n" },
  },
}

for prefix, kv in pairs(KeyMap) do
  for k, v in pairs(kv) do
    map(v.mode, "<leader>" .. prefix .. k, v[1], { desc = v[2] })
  end
end
