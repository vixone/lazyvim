return {
  -- Catppuccin colorscheme (Mocha dark / Latte light)
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    opts = {
      transparent_background = true,
      background = {
        light = "latte",
        dark = "mocha",
      },
    },
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "catppuccin",
    },
  },

  -- navigate lsp suggest with tab
  {
    "saghen/blink.cmp",
    opts = {
      keymap = {
        preset = "default",
        ["<CR>"] = { "accept", "fallback" },
        ["<Tab>"] = { "select_next", "fallback" },
        ["<S-Tab>"] = { "select_prev", "fallback" },
      },
    },
  },

  -- fix jsonc download error
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      -- Remove "jsonc" from ensure_installed
      if opts.ensure_installed then
        opts.ensure_installed = vim.tbl_filter(function(lang)
          return lang ~= "jsonc"
        end, opts.ensure_installed)
      end
    end,
  },

  -- CopilotChat extra keymap and default model
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    opts = {
      model = "gpt-5.2-codex",
    },
    keys = {
      { "<leader>am", "<cmd>CopilotChatModels<cr>", desc = "CopilotChat Models" },
    },
  },

  -- Disable Snacks explorer (replaced by mini-files)
  {
    "folke/snacks.nvim",
    keys = {
      { "<leader>e", false }, -- remove Snacks explorer binding (use mini.files instead)
      { "<leader>E", false }, -- remove Snacks explorer cwd binding
    },
    opts = {
      explorer = { enabled = false },
    },
  },

  -- -- Kitty + vim seamless navigation with ctrl+hjkl
  -- {
  --   "knubie/vim-kitty-navigator",
  --   build = "cp ./*.py ~/.config/kitty/",
  --   init = function()
  --     vim.g.kitty_navigator_no_mappings = 1
  --   end,
  --   keys = {
  --     { "<C-h>", "<cmd>KittyNavigateLeft<cr>", mode = { "n", "v", "i" }, desc = "KittyNavigateLeft" },
  --     { "<C-j>", "<cmd>KittyNavigateDown<cr>", mode = { "n", "v", "i" }, desc = "KittyNavigateDown" },
  --     { "<C-k>", "<cmd>KittyNavigateUp<cr>", mode = { "n", "v", "i" }, desc = "KittyNavigateUp" },
  --     { "<C-l>", "<cmd>KittyNavigateRight<cr>", mode = { "n", "v", "i" }, desc = "KittyNavigateRight" },
  --   },
  -- },
  --
  {
    "mrjones2014/smart-splits.nvim",
    lazy = false, -- must load eagerly so IS_NVIM user var is set before first keypress
    keys = {
      { "<C-h>", function() require("smart-splits").move_cursor_left() end, desc = "Move to left split/pane" },
      { "<C-j>", function() require("smart-splits").move_cursor_down() end, desc = "Move to below split/pane" },
      { "<C-k>", function() require("smart-splits").move_cursor_up() end, desc = "Move to above split/pane" },
      { "<C-l>", function() require("smart-splits").move_cursor_right() end, desc = "Move to right split/pane" },
    },
  },

  -- Disable bufferline tab bar — use <leader>b for buffer switching
  { "akinsho/bufferline.nvim", enabled = false },

  -- Lazygit
  {
    "kdheepak/lazygit.nvim",
    cmd = {
      "LazyGit",
      "LazyGitConfig",
      "LazyGitCurrentFile",
      "LazyGitFilter",
      "LazyGitFilterCurrentFile",
    },
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    keys = {
      { "<leader>gg", "<cmd>LazyGit<cr>", desc = "Open Lazygit" },
    },
  },
}
