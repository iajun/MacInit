-- Change '<C-g>' here to any keycode you like.
vim.keymap.set('i', '<C-y>', function() return vim.fn['codeium#Accept']() end, { expr = true })
vim.keymap.set('i', '<C-h>', function() return vim.fn['codeium#CycleCompletions'](1) end, { expr = true })
vim.keymap.set('i', '<C-l>', function() return vim.fn['codeium#CycleCompletions'](-1) end, { expr = true })
vim.keymap.set('i', '<c-x>', function() return vim.fn['codeium#Clear']() end, { expr = true })