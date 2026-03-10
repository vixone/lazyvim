-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- ─── THEME MODE SYNC ──────────────────────────────────────────────
-- Syncs vim background with ~/.config/wezterm/theme-mode
-- Toggle with: toggle-theme (shell) or CMD+SHIFT+T (WezTerm keybinding)
local theme_file = vim.fn.expand("~/.config/wezterm/theme-mode")

local function sync_theme()
  local f = io.open(theme_file, "r")
  if not f then
    return
  end
  local mode = f:read("*l")
  f:close()
  if mode and mode:match("light") then
    vim.o.background = "light"
  else
    vim.o.background = "dark"
  end
  -- Re-apply colorscheme so catppuccin picks up the background change
  pcall(vim.cmd.colorscheme, "catppuccin")
end

-- Sync on load
sync_theme()

-- Re-sync when nvim regains focus
vim.api.nvim_create_autocmd("FocusGained", {
  group = vim.api.nvim_create_augroup("theme_sync", { clear = true }),
  callback = sync_theme,
})

-- File watcher for instant sync (no focus switch needed)
local function watch_theme()
  local w = vim.uv.new_fs_event()
  if w then
    w:start(theme_file, {}, vim.schedule_wrap(function()
      w:stop()
      sync_theme()
      -- Re-arm watcher (file replacement invalidates the watch)
      vim.defer_fn(watch_theme, 100)
    end))
  end
end
watch_theme()

-- ─── UNCHECKED IDEAS SYNC ──────────────────────────────────────────
-- When Unchecked-Ideas.md is saved, sync checked items back to source notes
vim.api.nvim_create_autocmd("BufWritePost", {
  group = vim.api.nvim_create_augroup("unchecked_ideas_sync", { clear = true }),
  pattern = "*/obsidian-notes/Unchecked-Ideas.md",
  callback = function()
    -- Run sync script in background
    vim.fn.jobstart(vim.fn.expand("~/obsidian-notes/sync-checked-ideas.sh"), {
      on_exit = function(_, exit_code)
        if exit_code == 0 then
          -- Regenerate the ideas note to remove checked items
          vim.fn.jobstart(vim.fn.expand("~/obsidian-notes/generate-unchecked-ideas.sh"), {
            on_exit = function()
              -- Reload the buffer to show updated list
              vim.cmd("checktime")
            end,
          })
        end
      end,
    })
  end,
})
