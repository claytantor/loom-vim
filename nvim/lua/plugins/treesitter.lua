-- Determine treesitter branch based on Neovim version
-- 0.11.x → "master" (stable, pre-compiled parsers)
-- 0.12.x+ → "main" (requires tree-sitter CLI)
local v = vim.version()
local ts_branch = "master"
if v.major >= 1 or v.minor >= 12 then
  ts_branch = "main"
end

-- The `main` branch (Neovim 0.12+) removed nvim-treesitter.configs;
-- it uses declarative vim.treesitter API instead.
local config_fn
if ts_branch == "master" then
  config_fn = function()
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
  end
else
  -- main branch: use vim.treesitter directly; parsers auto-install on first open
  config_fn = function()
    local parser_list = {
      "lua", "python", "javascript", "typescript", "tsx",
      "bash", "json", "yaml", "toml",
      "markdown", "markdown_inline",
      "html", "css", "dockerfile", "sql", "rust",
    }
    -- Install parsers synchronously on first run
    for _, lang in ipairs(parser_list) do
      pcall(vim.treesitter.language.add, lang)
    end
    vim.treesitter.start()
  end
end

return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = ts_branch,
    build = ":TSUpdate",
    lazy = false,
    config = config_fn,
  },
}