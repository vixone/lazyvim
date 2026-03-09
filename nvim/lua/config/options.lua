-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
--
vim.g.have_nerd_font = true
vim.opt.swapfile = false

-- Set initial background from theme-mode file (before colorscheme loads)
local f = io.open(vim.fn.expand("~/.config/wezterm/theme-mode"), "r")
if f then
  local mode = f:read("*l")
  f:close()
  if mode and mode:match("light") then
    vim.o.background = "light"
  end
end
