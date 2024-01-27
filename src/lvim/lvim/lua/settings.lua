vim.o.termguicolors = true
vim.cmd.colorscheme "catppuccin-macchiato"

local opts_override = {
  relativenumber = true,
  wrap = true,
  foldmethod = "expr",
  autoread = true,
  foldexpr = "nvim_treesitter#foldexpr()",
}

for k, v in pairs(opts_override) do
  vim.opt[k] = v
end

vim.cmd [[
  autocmd BufReadPost * lua require'functions'.jump_to_last_pos()
]]
