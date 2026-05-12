local opt = vim.opt
opt.number = true
opt.relativenumber = true
opt.tabstop = 2
opt.shiftwidth = 2
opt.expandtab = true
opt.smartindent = true
opt.wrap = false
opt.swapfile = false
opt.backup = false
opt.undofile = true
opt.hlsearch = true
opt.incsearch = true
opt.termguicolors = true
opt.scrolloff = 8
opt.sidescrolloff = 8
opt.signcolumn = "yes"
opt.isfname:append("@-@")
opt.updatetime = 50
opt.colorcolumn = "120"
opt.splitbelow = true
opt.splitright = true
opt.mouse = "a"
if vim.env.SSH_TTY ~= nil or vim.env.SSH_CONNECTION ~= nil or vim.env.DISPLAY == nil or vim.env.DISPLAY == "" then
  vim.g.clipboard = {
    name = 'OSC 52',
    copy = {
      ['+'] = require('vim.ui.clipboard.osc52').copy('+'),
      ['*'] = require('vim.ui.clipboard.osc52').copy('*'),
    },
    paste = {
      ['+'] = require('vim.ui.clipboard.osc52').paste('+'),
      ['*'] = require('vim.ui.clipboard.osc52').paste('*'),
    },
  }
else
  opt.clipboard = "unnamedplus"
end
opt.ignorecase = true
opt.smartcase = true