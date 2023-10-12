local opts_override = {
  relativenumber = true,
  foldmethod = "expr",
  foldexpr = "nvim_treesitter#foldexpr()",
  clipboard = "none",
}
for k, v in pairs(opts_override) do
  vim.opt[k] = v
end

vim.api.nvim_create_autocmd({ "BufReadPost" }, {
  pattern = { "*" },
  command = [[if line("'\"") > 0 && line("'\"") <= line("$") | exe "normal! g`\"" | endif]],
})

