return {
  {
    "nvim-tree/nvim-tree.lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    keys = {
      { "<Leader>e", "<Cmd>NvimTreeToggle<CR>", desc = "Toggle file tree" },
      { "<Leader>ee", function()
        require("nvim-tree.api").tree.open()
        for _, win in ipairs(vim.api.nvim_list_wins()) do
          local buf = vim.api.nvim_win_get_buf(win)
          if vim.api.nvim_buf_get_name(buf) == ""
            and vim.api.nvim_buf_line_count(buf) == 1
            and vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == ""
            and vim.bo[buf].filetype ~= "NvimTree" then
            pcall(vim.api.nvim_win_close, win, false)
          end
        end
      end, desc = "Open file tree (close empty buffers)" },
      { "<Leader>ef", "<Cmd>NvimTreeFocus<CR>", desc = "Focus file tree" },
      { "<Leader>er", "<Cmd>NvimTreeRefresh<CR>", desc = "Refresh file tree" },
    },
    config = function(_, opts)
      opts.on_attach = function(bufnr)
        local api = require('nvim-tree.api')
        api.config.mappings.default_on_attach(bufnr)
        vim.keymap.set('n', 'n', function()
          local node = api.tree.get_node_under_cursor()
          if node and node.type == 'file' then
            local path = vim.fn.shellescape(node.absolute_path)
            local cur_win = vim.api.nvim_get_current_win()
            vim.cmd('wincmd l')
            if vim.api.nvim_get_current_win() == cur_win then
              vim.cmd('vsplit | terminal nano ' .. path)
              vim.cmd('wincmd h | vertical resize 32 | wincmd l')
            else
              vim.cmd('split | terminal nano ' .. path)
            end
            vim.cmd('startinsert')
          end
        end, { buffer = bufnr, noremap = true, silent = true, desc = 'Open in nano' })
      end
      require('nvim-tree').setup(opts)
    end,
    opts = {
      disable_netrw = true,
      hijack_netrw = true,
      view = { width = 32, side = "left" },
      renderer = {
        group_empty = true,
        icons = { show = { git = true, file = true, folder = true } },
      },
      filters = { dotfiles = false },
      git = { enable = true },
    },
  },
}