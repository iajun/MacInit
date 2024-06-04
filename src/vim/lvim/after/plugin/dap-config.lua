local mason_nvim_dap_status_ok, mv_dap = pcall(require, "mason-nvim-dap")
if not mason_nvim_dap_status_ok then
  return
end

mv_dap.setup({
  ensure_installed = { "python", "node2", "chrome", "php", "js", "rust", "bash", "javadbg", "javatest" },
  automatic_setup = true,
  handlers = {
    function(config)
      -- all sources with no handler get passed here

      -- Keep original functionality
      require('mason-nvim-dap').default_setup(config)
    end,
  }
})

-- dap.configurations.typescript = {
--   {
--     name = "Launch",
--     type = "node2",
--     request = "launch",
--     program = "${file}",
--     cwd = vim.fn.getcwd(),
--     sourceMaps = true,
--     protocol = "inspector",
--     console = "integratedTerminal",
--   },
--   {
--     -- For this to work you need to make sure the node process is started with the `--inspect` flag.
--     name = "Attach to process",
--     type = "node2",
--     request = "attach",
--     processId = require("dap.utils").pick_process,
--   },
-- }

-- -- dap.configurations.typescript = {
-- --   {
-- --     type = "chrome",
-- --     request = "attach",
-- --     program = "${file}",
-- --     debugServer = 45635,
-- --     cwd = vim.fn.getcwd(),
-- --     sourceMaps = true,
-- --     protocol = "inspector",
-- --     port = 9222,
-- --     webRoot = "${workspaceFolder}"
-- --   }
-- -- }
