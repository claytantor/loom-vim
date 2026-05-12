-- Core keymaps (not plugin-specific; plugin keymaps live in their plugin specs)
local map = vim.keymap.set

-- Quality of Life
map("n", "<Esc><Esc>", "<Cmd>nohlsearch<CR>", { desc = "Clear search highlights" })
map("n", "<Leader>w", "<Cmd>write<CR>", { desc = "Save file" })
map("i", "jk", "<Esc>", { desc = "Escape insert mode" })

-- Buffer Management
map("n", "<Leader>bd", "<Cmd>bdelete<CR>", { desc = "Delete buffer" })
map("n", "<Tab>", "<Cmd>bnext<CR>", { desc = "Next buffer" })
map("n", "<S-Tab>", "<Cmd>bprevious<CR>", { desc = "Previous buffer" })

-- Window Splits
map("n", "<Leader>wv", "<Cmd>vsplit<CR>", { desc = "Vertical split" })
map("n", "<Leader>wh", "<Cmd>split<CR>", { desc = "Horizontal split" })
map("n", "<Leader>wq", "<Cmd>close<CR>", { desc = "Close window" })
map("n", "<C-h>", "<C-w>h", { desc = "Move to left window" })
map("n", "<C-j>", "<C-w>j", { desc = "Move to below window" })
map("n", "<C-k>", "<C-w>k", { desc = "Move to above window" })
map("n", "<C-l>", "<C-w>l", { desc = "Move to right window" })