-- nvim-treesitter has two incompatible APIs:
--   * `master` branch (Neovim 0.11): `require("nvim-treesitter.configs").setup{}`
--   * `main` branch  (Neovim 0.12+): `require("nvim-treesitter").install{}`
-- The branch lazy.nvim should track is decided by Neovim version, but the
-- *config callback* detects the API by which module is actually on disk —
-- that way a version/branch drift (e.g. upgrading Neovim without re-running
-- the installer, or two nvims sharing one config dir) can't break startup.

local langs = {
  "lua", "python", "javascript", "typescript", "tsx",
  "bash", "json", "yaml", "toml",
  "markdown", "markdown_inline",
  "html", "css", "dockerfile", "sql", "rust",
}

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
      local has_configs, configs = pcall(require, "nvim-treesitter.configs")
      if has_configs then
        configs.setup({
          ensure_installed = langs,
          auto_install = true,
          highlight = { enable = true },
          indent = { enable = true },
        })
        return
      end
      -- main-branch plugin requires Neovim >= 0.10 (uses vim.fs.joinpath etc.).
      -- On older Neovim, silently skip so the rest of the config still loads.
      if not (vim.fs and vim.fs.joinpath) then
        vim.notify("loom-vim: skipping nvim-treesitter (needs Neovim >= 0.10)", vim.log.levels.WARN)
        return
      end
      local has_ts, ts = pcall(require, "nvim-treesitter")
      if has_ts and type(ts.install) == "function" then
        pcall(ts.install, langs)
      end
    end,
  },
}
