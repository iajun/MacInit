lvim.builtin.telescope.defaults = vim.tbl_extend("force", lvim.builtin.telescope.defaults, {
  file_ignore_patterns = {
    "node_modules",
    ".yarnrc"
  },
  vimgrep_arguments = {
  "ag",
  "--vimgrep",
  "--hidden",
  "--ignore",
  "node_modules",
  "--ignore",
  ".yarnrc",
  "--ignore",
  ".git",
}
})

lvim.builtin.telescope.pickers = vim.tbl_extend("force", lvim.builtin.telescope.pickers, {
  find_files = {
    hidden = true,
    find_command = { "ag", "-g", "." },
  }
})

