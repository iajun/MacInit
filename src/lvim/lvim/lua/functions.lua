local M = {}

M.jump_to_last_pos = function()
  local line = vim.fn.line([['"]])
  local col = vim.fn.col([['"]])
  local last_line = vim.fn.line("$")

  if line > 0 and line <= last_line then
    vim.api.nvim_win_set_cursor(0, { line, col - 1 })
  end
end

return M
