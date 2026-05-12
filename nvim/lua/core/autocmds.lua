-- FileType autocommands: treesitter highlighting, folding, indentation
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("TreesitterConfig", { clear = true }),
  callback = function()
    pcall(vim.treesitter.start)
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("TreesitterFold", { clear = true }),
  callback = function()
    vim.wo[0][0].foldexpr = "v:lua.vim.treesitter.foldexpr()"
    vim.wo[0][0].foldmethod = "expr"
    vim.wo[0][0].foldenable = false -- open all folds by default
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("TreesitterIndent", { clear = true }),
  callback = function()
    pcall(function()
      vim.bo[0].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
    end)
  end,
})

-- Auto-open nvim-tree when nvim is launched with a directory argument
vim.api.nvim_create_autocmd("VimEnter", {
  group = vim.api.nvim_create_augroup("NvimTreeDir", { clear = true }),
  callback = function(data)
    if data.file and vim.fn.isdirectory(data.file) == 1 then
      vim.cmd("NvimTreeOpen")
    end
  end,
})