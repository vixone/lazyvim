-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
-- Delete without yanking (copying to register)
vim.keymap.set("n", "dd", '"_dd', { desc = "Delete line without yanking" })
vim.keymap.set("n", "d", '"_d', { desc = "Delete without yanking" })
vim.keymap.set("v", "d", '"_d', { desc = "Delete without yanking" })

-- For text objects like di(, da", etc.
vim.keymap.set("n", "di", '"_di', { desc = "Delete inside without yanking" })
vim.keymap.set("n", "da", '"_da', { desc = "Delete around without yanking" })
vim.keymap.set("n", "ci", '"_ci', { desc = "Change inside without yanking" })
vim.keymap.set("n", "ca", '"_ca', { desc = "Change around without yanking" })
