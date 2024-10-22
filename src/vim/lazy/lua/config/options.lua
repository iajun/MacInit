-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

local function open_external(file)
  local sysname = vim.loop.os_uname().sysname:lower()
  local jobcmd
  if sysname:match("windows") then
    jobcmd = ("start %s"):format(file)
  else
    -- Note sure if this is correct. I just copied it from the other answers.
    jobcmd = { "open", file }
  end
  local job = vim.fn.jobstart(jobcmd, {
    -- Don't kill the started process when nvim exits.
    detach = true,

    -- Make relative paths relative to the current file.
    cwd = vim.fn.expand("%:p:h"),
  })
  -- Kill the job after 5 seconds.
  local delay = 5000
  vim.defer_fn(function()
    vim.fn.jobstop(job)
  end, delay)
end
vim.keymap.set("n", "gx", function()
  open_external(vim.fn.expand("<cfile>"))
end)

local opts_override = {
  relativenumber = true,
  wrap = true,
  termguicolors = true,
  autoread = true,
}

for k, v in pairs(opts_override) do
  vim.opt[k] = v
end
