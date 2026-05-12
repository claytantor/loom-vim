return {
  {
    "nvim-tree/nvim-tree.lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    keys = {
      { "<Leader>e", "<Cmd>NvimTreeToggle<CR>", desc = "Toggle file tree" },
      { "<Leader>ef", "<Cmd>NvimTreeFocus<CR>", desc = "Focus file tree" },
      { "<Leader>er", "<Cmd>NvimTreeRefresh<CR>", desc = "Refresh file tree" },
    },
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