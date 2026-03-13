# nvim-mini: Stability-First Neovim Config Rebuild

**Date:** 2026-03-13
**Status:** Approved
**Goal:** Replace LazyVim with a mini.nvim-based config that prioritizes stability, portability, and full user control.

## Core Decisions

- **Primary motivation:** Stability above all
- **Approach:** Hybrid — mini.nvim core + targeted best-of-breed plugins
- **Install location:** `~/.config/nvim-mini` (side-by-side via `NVIM_APPNAME`)
- **Plugin count:** ~16 (vs LazyVim's ~40+), 10 from one repo (mini.nvim)

## Architecture

```
~/.config/nvim-mini/
  init.lua                    # Entry point - bootstrap lazy.nvim, load config
  lua/
    config/
      options.lua            # Vim options (loaded first)
      keymaps.lua            # Custom keymaps (black-hole deletes, etc.)
      autocmds.lua           # Autocommands
    plugins/
      mini.lua               # All 10 mini.nvim modules - ONE plugin, ONE file
      lsp.lua                # lspconfig + mason + conform + nvim-lint
      editor.lua             # which-key, treesitter, gitsigns
      coding.lua             # blink.cmp, copilot, copilot-chat
      ui.lua                 # catppuccin, render-markdown
      git.lua                # lazygit
      navigation.lua         # smart-splits
  lazy-lock.json             # Pinned versions - stability guarantee
```

## Plugin Manifest

### mini.nvim (1 repo = 10 features)

| Module | Replaces | Purpose |
|--------|----------|---------|
| mini.files | snacks.explorer | File tree |
| mini.pick + mini.extra | snacks.picker | Grep, buffers, files |
| mini.statusline | lualine | Bottom bar |
| mini.pairs | mini.pairs | Auto-close brackets |
| mini.comment | ts-context-commentstring | gc/gcc commenting |
| mini.starter | mini.starter | Start screen |
| mini.notify | snacks.notifier | Notifications |
| mini.indentscope | snacks.indent | Animated indent guide |
| mini.icons | nvim-web-devicons | File type icons |
| mini.sessions | persistence.nvim | Session save/restore |

### Standalone Plugins

| Plugin | Why standalone |
|--------|---------------|
| lazy.nvim | Plugin manager |
| nvim-lspconfig + mason + mason-lspconfig | LSP setup |
| conform.nvim | Formatting |
| nvim-lint | Linting |
| which-key.nvim | Keybinding discovery |
| nvim-treesitter | Syntax highlighting |
| gitsigns.nvim | Git gutter signs |
| lazygit.nvim | Git UI |
| blink.cmp | Code completion |
| copilot.lua + CopilotChat.nvim | AI assistance |
| catppuccin | Colorscheme |
| smart-splits.nvim | WezTerm pane navigation |
| render-markdown.nvim | Markdown rendering |

## LSP Servers (all lazy-loaded by filetype)

| Language | Server | Formatter | Linter |
|----------|--------|-----------|--------|
| Python | pyright | ruff | ruff |
| Terraform | terraform-ls | terraform fmt | tflint |
| Ansible | ansiblels | - | ansible-lint |
| Markdown | markdown-oxide | - | - |
| Bash/Shell | bashls | shfmt | shellcheck |
| JavaScript/Node | ts_ls | prettier | eslint |
| JSON | jsonls | prettier | - |
| Lua | lua_ls | stylua | - |
| YAML | yamlls | - | - |

## Keybindings (LazyVim muscle memory preserved)

- `<leader>e` — mini.files (file dir)
- `<leader>E` — mini.files (cwd)
- `<leader>sg` — live grep (mini.pick)
- `<leader>,` — buffer switching (mini.pick)
- `<leader>ff` — find files (mini.pick)
- `<leader>gg` — lazygit
- `gc` / `gcc` — comment toggle
- `d`, `dd` — delete without yanking (black hole register)
- `di`, `da`, `ci`, `ca` — delete/change inside/around without yanking

## Stability Strategy

1. `lazy-lock.json` committed to git — exact commit hashes
2. Update on YOUR schedule — `:Lazy update` only when you choose
3. Rollback: `git checkout lazy-lock.json` + `:Lazy restore`
4. No framework dependency — no LazyVim middleman

## Side-by-Side Testing

```bash
NVIM_APPNAME=nvim-mini nvim        # Test new config
alias vm='NVIM_APPNAME=nvim-mini nvim'  # Alias for convenience
```

## What's Intentionally Excluded

- flash.nvim (jump navigation) — not used
- mini.surround — not used
- trouble.nvim — use built-in vim.diagnostic
- todo-comments — not needed
- bufferline — already disabled
- snacks.nvim — replaced entirely by mini.nvim modules
- LazyVim framework — replaced by direct plugin config

## Parking Lot (future additions if needed)

- todo-comments.nvim — if you miss TODO highlighting
- mini.surround — if you start wanting surround operations
- Additional language servers — add to lsp.lua as needed
