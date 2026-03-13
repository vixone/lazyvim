-- Markdown / Obsidian daily notes workflow
-- Plugins: markdown-oxide (LSP), render-markdown (visual)

return {
  -- ─── MASON: ensure markdown LSPs are installed ────────────────────
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      vim.list_extend(opts.ensure_installed, {
        "markdown-oxide",
      })
    end,
  },

  -- ─── LSP CONFIG: markdown-oxide ──────────────────────────────────
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        -- Disable marksman (LazyVim default) in favor of markdown-oxide
        marksman = { enabled = false },

        -- markdown-oxide: wiki links, references, completions, daily notes
        -- Hover (K) shows link previews, gd goes to definition, gr finds references
        -- <leader>ss searches document symbols (headers!)
        markdown_oxide = {
          -- Only add the extra capability - LazyVim merges this with blink.cmp caps
          capabilities = {
            workspace = {
              didChangeWatchedFiles = {
                dynamicRegistration = true,
              },
            },
          },
        },

        -- harper_ls disabled - too noisy for quick-capture daily notes
        harper_ls = { enabled = false },
      },
    },
  },

  -- ─── RENDER MARKDOWN: visual rendering in the buffer ──────────────
  {
    "MeanderingProgrammer/render-markdown.nvim",
    enabled = true,
    opts = {
      bullet = { enabled = true },
      checkbox = {
        enabled = true,
        position = "inline",
        unchecked = {
          icon = "   󰄱 ",
          highlight = "RenderMarkdownUnchecked",
        },
        checked = {
          icon = "   󰱒 ",
          highlight = "RenderMarkdownChecked",
        },
      },
      heading = {
        sign = false,
        icons = { "󰎤 ", "󰎧 ", "󰎪 ", "󰎭 ", "󰎱 ", "󰎳 " },
      },
      code = {
        style = "full",
      },
    },
  },

  -- ─── MARKDOWN KEYMAPS ────────────────────────────────────────────
  -- <leader>gd: create note from unresolved [[wiki link]]
  -- <CR>: toggle checkbox / fold-unfold header / default enter
  -- o: continue list/checkbox on new line
  {
    "neovim/nvim-lspconfig",
    keys = {
      { "<leader>gd", vim.lsp.buf.code_action, desc = "Create linked note", ft = "markdown" },
    },
    init = function()
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "markdown",
        callback = function(args)
          -- Custom markdown folding: h2+ fold, h1 never folds (it's the title)
          _G.MarkdownFold = function()
            local line = vim.fn.getline(vim.v.lnum)
            local hashes = line:match("^(#+) ")
            if hashes then
              local depth = #hashes
              if depth == 1 then return "0" end -- h1 = no fold
              return ">" .. (depth - 1) -- h2 = level 1, h3 = level 2, etc.
            end
            return "="
          end
          vim.wo.foldmethod = "expr"
          vim.wo.foldexpr = "v:lua.MarkdownFold()"
          vim.wo.foldlevel = 99 -- start with all folds open

          -- <CR>: checkbox toggle / header fold (h2+ only) / default enter
          vim.keymap.set("n", "<CR>", function()
            local line = vim.api.nvim_get_current_line()
            if line:match("%[x%]") then
              vim.api.nvim_set_current_line((line:gsub("%[x%]", "[ ]", 1)))
            elseif line:match("%[ %]") then
              vim.api.nvim_set_current_line((line:gsub("%[ %]", "[x]", 1)))
            elseif line:match("^##+ ") then
              -- Toggle fold on h2+ header lines (skip h1 title)
              vim.cmd("normal! za")
            else
              vim.cmd("normal! j")
            end
          end, { buffer = args.buf, desc = "Toggle checkbox / fold header" })

          -- Continue list/checkbox on 'o'
          vim.keymap.set("n", "o", function()
            local line = vim.api.nvim_get_current_line()
            local row = vim.api.nvim_win_get_cursor(0)[1]
            local indent = line:match("^(%s*)")

            local new_line
            -- Checkbox: "- [ ]" or "- [x]" (with or without text after)
            if line:match("^%s*- %[.%]") then
              new_line = indent .. "- [ ] "
            -- Numbered list: "1. something"
            elseif line:match("^%s*%d+%.%s") then
              local num = tonumber(line:match("^%s*(%d+)"))
              new_line = indent .. (num + 1) .. ". "
            -- Bullet: "- something" (but not "- [" which is a checkbox)
            elseif line:match("^%s*- %S") and not line:match("^%s*- %[") then
              new_line = indent .. "- "
            end

            if new_line then
              vim.fn.append(row, new_line)
              vim.api.nvim_win_set_cursor(0, { row + 1, #new_line })
              vim.cmd("startinsert!")
            else
              -- Default o behavior
              vim.fn.append(row, "")
              vim.api.nvim_win_set_cursor(0, { row + 1, 0 })
              vim.cmd("startinsert!")
            end
          end, { buffer = args.buf, desc = "Continue list item" })
        end,
      })
    end,
  },

  -- ─── TREESITTER: ensure markdown parsers are installed ────────────
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      vim.list_extend(opts.ensure_installed, {
        "markdown",
        "markdown_inline",
      })
    end,
  },
}
