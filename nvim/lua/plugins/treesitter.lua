-- Determine treesitter branch based on Neovim version
-- 0.11.x → "master" (stable, pre-compiled parsers)
-- 0.12.x+ → "main" (requires tree-sitter CLI)
local v = vim.version()
local ts_branch = "master"
if v.major >= 1 or v.minor >= 12 then
  ts_branch = "main"
end

return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = ts_branch,
    build = ":TSUpdate",
    lazy = false,
    config = function()
      require("nvim-treesitter.configs").setup({
        ensure_installed = {
          "lua", "python", "javascript", "typescript", "tsx",
          "bash", "json", "yaml", "toml",
          "markdown", "markdown_inline",
          "html", "css", "dockerfile", "sql", "rust",
        },
        auto_install = true,
        highlight = { enable = true },
        indent = { enable = true },
      })
    end,
  },
}