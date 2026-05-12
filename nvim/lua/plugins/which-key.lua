return {
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      delay = 500,
    },
    keys = {
      { "<Leader>?", "<Cmd>WhichKey<CR>", desc = "Show all keymaps" },
    },
    config = function(_, opts)
      require("which-key").setup(opts)
      require("which-key").add({
        { "<Leader>f", group = "Find (Telescope)" },
        { "<Leader>e", group = "Explorer (nvim-tree)" },
        { "<Leader>b", group = "Buffers" },
        { "<Leader>g", group = "Git" },
        { "<Leader>l", group = "LSP" },
        { "<Leader>w", group = "Windows/splits" },
      })
    end,
  },
}