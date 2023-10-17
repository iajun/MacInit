require("gitsigns").setup({
  signs = {
    add          = { text = '+' },
    change       = { text = '~' },
    delete       = { text = '_' },
    topdelete    = { text = '‾' },
    changedelete = { text = '~' },
    untracked    = { text = '┆' },
  },
})

require('functions').register_normal_keymaps({
  ["<leader>gs"] = "<cmd>lua require('gitsigns').stage_hunk()<CR>",
  ["<leader>gr"] = "<cmd>lua require('gitsigns').reset_hunk()<CR>",
  ["<leader>gS"] = "<cmd>lua require('gitsigns').stage_buffer()<CR>",
  ["<leader>gu"] = "<cmd>lua require('gitsigns').undo_stage_hunk()<CR>",
  ["<leader>gR"] = "<cmd>lua require('gitsigns').reset_buffer()<CR>",
  ["<leader>gp"] = "<cmd>lua require('gitsigns').preview_hunk()<CR>",
  ["<leader>gb"] = "<cmd>lua require('gitsigns').blame_line()<CR>",
  ["<leader>gd"] = "<cmd>lua require('gitsigns').diffthis()<CR>",
})

