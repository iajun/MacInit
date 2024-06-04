local M = {}

M.jump_to_last_pos = function()
  local line = vim.fn.line([['"]])
  local col = vim.fn.col([['"]])
  local last_line = vim.fn.line("$")

  if line > 0 and line <= last_line then
    vim.api.nvim_win_set_cursor(0, { line, col - 1 })
  end
end

M.register_normal_keymaps = function(mappings)
  for key, value in pairs(mappings) do
    vim.keymap.set("n", key, value, { noremap = true })
  end
end

M.register_insert_keymaps = function(mappings)
  for key, value in pairs(mappings) do
    vim.keymap.set("i", key, value, { noremap = true })
  end
end

return M
