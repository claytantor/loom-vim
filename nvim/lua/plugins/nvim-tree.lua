return {
  {
    "nvim-tree/nvim-tree.lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    keys = {
      { "<Leader>e", "<Cmd>NvimTreeToggle<CR>", desc = "Toggle file tree" },
      { "<Leader>ef", "<Cmd>NvimTreeFocus<CR>", desc = "Focus file tree" },
      { "<Leader>er", "<Cmd>NvimTreeRefresh<CR>", desc = "Refresh file tree" },
    },
    config = function(_, opts)
      opts.on_attach = function(bufnr)
        local api = require('nvim-tree.api')
        api.config.mappings.default_on_attach(bufnr)
        vim.keymap.set('n', '<Leader>vi', function()
          local node = api.tree.get_node_under_cursor()
          if node and node.type == 'file' then
            vim.cmd('split | terminal vi ' .. vim.fn.shellescape(node.absolute_path))
          end
        end, { buffer = bufnr, noremap = true, silent = true, desc = 'Open in vi' })
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