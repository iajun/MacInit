lvim.plugins = {
  {
    "tpope/vim-surround",
    "mg979/vim-visual-multi",
    "arcticicestudio/nord-vim",
    {
      "windwp/nvim-ts-autotag",
      config = function()
        require'nvim-treesitter.configs'.setup {
  autotag = {
    enable = true,
    enable_rename = true,
    enable_close = true,
    enable_close_on_slash = true,
    filetypes = { "html" , "xml" },
  }
}
      end
    },
    {
      "phaazon/hop.nvim",
      branch = 'v2',
      event = "BufRead",
      config = function()
        require("hop").setup({
          case_insensitive = false,
          multi_windows = true,
        })
        local hop = require('hop')
        local directions = require('hop.hint').HintDirection
        vim.keymap.set('', 'f', function()
          hop.hint_char1({ direction = directions.AFTER_CURSOR, current_line_only = true })
        end, { remap = true })
        vim.keymap.set('', 'F', function()
          hop.hint_char1({ direction = directions.BEFORE_CURSOR, current_line_only = true })
        end, { remap = true })
        vim.keymap.set('', 't', function()
          hop.hint_char1({ direction = directions.AFTER_CURSOR, current_line_only = true, hint_offset = -1 })
        end, { remap = true })
        vim.keymap.set('', '<leader>t', function()
          hop.hint_char1({ direction = directions.AFTER_CURSOR })
        end, { remap = true })
        vim.keymap.set('', '<leader>T', function()
          hop.hint_char1({ direction = directions.BEFORE_CURSOR })
        end, { remap = true })
      end,
    },
    {
      "nvim-treesitter/nvim-treesitter-textobjects",
      after = "nvim-treesitter",
      requires = "nvim-treesitter/nvim-treesitter",
      config = function()
        require 'nvim-treesitter.configs'.setup {
          textobjects = {
            select = {
              enable = true,

              -- Automatically jump forward to textobj, similar to targets.vim
              lookahead = true,

              keymaps = {
                -- You can use the capture groups defined in textobjects.scm
                ["af"] = "@function.outer",
                ["if"] = "@function.inner",
                ["ac"] = "@class.outer",
                -- You can optionally set descriptions to the mappings (used in the desc parameter of
                -- nvim_buf_set_keymap) which plugins like which-key display
                ["ic"] = { query = "@class.inner", desc = "Select inner part of a class region" },
                -- You can also use captures from other query groups like `locals.scm`
                ["as"] = { query = "@scope", query_group = "locals", desc = "Select language scope" },
              },
              -- You can choose the select mode (default is charwise 'v')
              --
              -- Can also be a function which gets passed a table with the keys
              -- * query_string: eg '@function.inner'
              -- * method: eg 'v' or 'o'
              -- and should return the mode ('v', 'V', or '<c-v>') or a table
              -- mapping query_strings to modes.
              selection_modes = {
                ['@parameter.outer'] = 'v', -- charwise
                ['@function.outer'] = 'V',  -- linewise
                ['@class.outer'] = '<c-v>', -- blockwise
              },
              -- If you set this to `true` (default is `false`) then any textobject is
              -- extended to include preceding or succeeding whitespace. Succeeding
              -- whitespace has priority in order to act similarly to eg the built-in
              -- `ap`.
              --
              -- Can also be a function which gets passed a table with the keys
              -- * query_string: eg '@function.inner'
              -- * selection_mode: eg 'v'
              -- and should return true of false
              include_surrounding_whitespace = true,
            },
          },
        }
      end
    },
    {
      "zbirenbaum/copilot.lua",
      config = function()
        require("copilot").setup({
          suggestion = { enabled = false },
          panel = { enabled = false },
        })
      end,
    },
    {
      "zbirenbaum/copilot-cmp",
      after = { "copilot.lua" },
      config = function()
        require("copilot_cmp").setup()
      end
    },
  }
}
