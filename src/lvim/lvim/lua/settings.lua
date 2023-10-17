local opts_override = {
  relativenumber = true,
  foldmethod = "expr",
  foldexpr = "nvim_treesitter#foldexpr()",
  clipboard = "",
}

vim.cmd.colorscheme "catppuccin"

for k, v in pairs(opts_override) do
  vim.opt[k] = v
end

vim.cmd [[
  autocmd BufReadPost * lua require'functions'.jump_to_last_pos()
]]

