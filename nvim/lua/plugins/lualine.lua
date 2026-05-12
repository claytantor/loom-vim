return {
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    event = "VeryLazy",
    opts = {
      options = {
        theme = "auto",
      },
      sections = {
        lualine_a = { "mode" },
        lualine_b = { "branch", "diff" },
        lualine_c = { { "filename", path = 1, symbols = { modified = " [+]", readonly = " [RO]" } } },
        lualine_x = { { "diagnostics", sources = { "nvim_diagnostic" } }, "filetype" },
        lualine_y = { "location" },
        lualine_z = { "progress" },
      },
    },
  },
}