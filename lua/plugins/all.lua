return {
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

  -- Snacks explorer: use cwd instead of project root
  {
    "folke/snacks.nvim",
    keys = {
      { "<leader>e", function() Snacks.explorer.open({ cwd = vim.fn.getcwd() }) end, desc = "Explorer (cwd)" },
    },
  },

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
