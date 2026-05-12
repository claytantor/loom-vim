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

-- Auto-open nvim-tree on startup; close the empty buffer when no file is given
vim.api.nvim_create_autocmd("VimEnter", {
  group = vim.api.nvim_create_augroup("NvimTreeDir", { clear = true }),
  callback = function(data)
    local is_dir = data.file and vim.fn.isdirectory(data.file) == 1
    local is_no_args = vim.fn.argc() == 0

    if not is_dir and not is_no_args then
      return
    end

    require("nvim-tree.api").tree.open()

    if is_no_args then
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        local buf = vim.api.nvim_win_get_buf(win)
        if vim.api.nvim_buf_get_name(buf) == ""
          and vim.api.nvim_buf_line_count(buf) == 1
          and vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == ""
          and vim.bo[buf].filetype ~= "NvimTree" then
          pcall(vim.api.nvim_win_close, win, false)
        end
      end
    end
  end,
})