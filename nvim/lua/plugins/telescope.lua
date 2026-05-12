return {
  {
    "nvim-telescope/telescope.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      {
        "nvim-telescope/telescope-fzf-native.nvim",
        build = "make",
      },
    },
    keys = {
      { "<Leader>ff", "<Cmd>Telescope find_files<CR>", desc = "Find files" },
      { "<Leader>fg", "<Cmd>Telescope live_grep<CR>", desc = "Live grep" },
      { "<Leader>fw", "<Cmd>Telescope grep_string<CR>", desc = "Grep word under cursor" },
      { "<Leader>fb", "<Cmd>Telescope buffers<CR>", desc = "List buffers" },
      { "<Leader>fh", "<Cmd>Telescope help_tags<CR>", desc = "Search help" },
      { "<Leader>fk", "<Cmd>Telescope keymaps<CR>", desc = "Search keymaps" },
      { "<Leader>fr", "<Cmd>Telescope oldfiles<CR>", desc = "Recent files" },
      { "<Leader>fc", "<Cmd>Telescope current_buffer_fuzzy_find<CR>", desc = "Find in buffer" },
    },
    config = function()
      require("telescope").setup({
        defaults = {
          layout_strategy = "horizontal",
          layout_config = { preview_width = 0.55 },
          path_display = { "truncate" },
          file_ignore_patterns = { "node_modules", ".git/", "dist/", "__pycache__" },
        },
      })
      require("telescope").load_extension("fzf")
    end,
  },
}