-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Set leader BEFORE loading plugins
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Load config modules
require("core.options")
require("core.keymaps")
require("core.autocmds")
require("lazy").setup({ import = "plugins" })