# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a Neovim configuration based on [LazyVim](https://lazyvim.github.io/). LazyVim is a Neovim setup powered by lazy.nvim, providing sensible defaults and a plugin ecosystem.

## Architecture

```
init.lua                    # Entry point - loads config.lazy
lua/
  config/
    lazy.lua               # lazy.nvim bootstrap and plugin spec setup
    options.lua            # Vim options (loaded before lazy.nvim)
    keymaps.lua            # Custom keymaps (loaded on VeryLazy event)
    autocmds.lua           # Autocommands (loaded on VeryLazy event)
  plugins/
    *.lua                  # Plugin specs - all files auto-loaded by lazy.nvim
lazyvim.json               # LazyVim extras configuration
```

## Enabled LazyVim Extras

Configured in `lazyvim.json`:
- `ai.copilot` and `ai.copilot-chat` - GitHub Copilot integration
- `lang.markdown` - Markdown support
- `lang.python` - Python LSP, formatting, linting
- `lang.terraform` - Terraform/HCL support

## Custom Plugin Modifications

In `lua/plugins/all.lua`:
- **blink.cmp**: Tab/Shift-Tab for completion navigation, Enter to accept
- **treesitter**: `jsonc` parser removed from ensure_installed (download error workaround)
- **lazygit**: Available via `<leader>gg`

## Custom Keymaps

Delete operations use the black hole register (`"_`) to avoid overwriting the clipboard:
- `d`, `dd` - delete without yanking
- `di`, `da`, `ci`, `ca` - delete/change inside/around without yanking

## Working with This Config

**Reload config without restarting Neovim:**
- `:Lazy sync` - Update/install plugins
- `:LazyExtras` - Toggle LazyVim extras

**Adding plugins:** Create a new `.lua` file in `lua/plugins/` returning a table of plugin specs. See `example.lua` for patterns.

**Overriding LazyVim defaults:** Return a spec with the same plugin name and your custom `opts` table or function.
