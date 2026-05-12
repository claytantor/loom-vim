#!/usr/bin/env bash
set -euo pipefail

# ─── Config ──────────────────────────────────────────────────────────────────
REPO_RAW="https://raw.githubusercontent.com/claytantor/loom-vim/main"
NVIM_CONFIG="$HOME/.config/nvim"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SENTINEL=".nvim-ide-managed"
DRY_RUN=false
NO_BACKUP=false

# ─── Argument Parsing ────────────────────────────────────────────────────────
for arg in "$@"; do
  case "$arg" in
    --dry-run)   DRY_RUN=true ;;
    --no-backup) NO_BACKUP=true ;;
    --help|-h)
      echo "Usage: bash install.sh [--dry-run] [--no-backup]"
      echo ""
      echo "  --dry-run    Print what would be done without making changes"
      echo "  --no-backup  Do not back up existing nvim config"
      exit 0
      ;;
    *) echo "Unknown argument: $arg"; exit 1 ;;
  esac
done

# ─── Colors / Helpers ────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()    { printf "${CYAN}[INFO]${NC}  %s\n" "$1"; }
warn()    { printf "${YELLOW}[WARN]${NC}  %s\n" "$1"; }
success() { printf "${GREEN}[ OK ]${NC}  %s\n" "$1"; }
error()   { printf "${RED}[ERR]${NC}  %s\n" "$1" >&2; }

run() {
  if $DRY_RUN; then
    printf "${BOLD}[DRY]${NC}   %s\n" "$*"
  else
    "$@"
  fi
}

# ─── 1. Detect OS ───────────────────────────────────────────────────────────
detect_os() {
  local os
  if [[ "$(uname -s)" == "Darwin" ]]; then
    os="macos"
  elif [[ -f /etc/debian_version ]]; then
    os="debian"
  elif [[ -f /etc/os-release ]]; then
    os="linux"
  else
    os="unknown"
  fi
  echo "$os"
}

# ─── 2. Check Neovim Version ────────────────────────────────────────────────
check_nvim() {
  if ! command -v nvim &>/dev/null; then
    error "Neovim is not installed. Install with:"
    error "  macOS:   brew install neovim"
    error "  Ubuntu:  apt install neovim   (or use AppImage)"
    exit 1
  fi

  local version
  version=$(nvim --version | head -n1 | sed -E 's/^NVIM v?([0-9]+\.[0-9]+).*/\1/')
  local major minor
  IFS='.' read -r major minor <<< "$version"

  if [[ -z "${major:-}" || -z "${minor:-}" ]]; then
    error "Could not parse Neovim version from: $(nvim --version | head -n1)"
    exit 1
  fi

  if [[ "$major" -lt 1 && "$minor" -lt 11 ]]; then
    error "Neovim $version detected; loom-vim requires >= 0.11"
    error "Upgrade with: brew install neovim  (macOS) or use an AppImage (Linux)"
    exit 1
  fi

  # Determine treesitter branch (used only for dependency-warning purposes;
  # the deployed treesitter.lua re-detects this at runtime via vim.version()).
  local ts_branch="master"
  if [[ "$major" -ge 1 ]] || [[ "$minor" -ge 12 ]]; then
    ts_branch="main"
  fi

  info "Neovim ${version} detected → treesitter branch: ${ts_branch}"
  echo "$ts_branch"
}

# ─── 3. Check System Dependencies ───────────────────────────────────────────
check_deps() {
  local ts_branch="${1:-master}"
  local missing=0
  local deps=(git rg fd make gcc)
  local names=(git ripgrep fd make gcc)

  for i in "${!deps[@]}"; do
    if ! command -v "${deps[$i]}" &>/dev/null; then
      warn "${names[$i]} is not installed"
      missing=1
    else
      success "${names[$i]} found"
    fi
  done

  # tree-sitter CLI is only required for the `main` branch (Neovim 0.12+)
  if [[ "$ts_branch" == "main" ]]; then
    if ! command -v tree-sitter &>/dev/null; then
      warn "tree-sitter CLI is not installed (required for nvim-treesitter 'main' branch on Neovim 0.12+)"
      warn "  macOS:  brew install tree-sitter"
      warn "  Linux:  cargo install tree-sitter-cli   (or your distro's package)"
      missing=1
    else
      success "tree-sitter found"
    fi
  fi

  if [[ "$missing" -eq 1 ]]; then
    warn "Some dependencies are missing; install them before proceeding."
    warn "See https://github.com/claytantor/loom-vim#system-dependencies for guidance."
  fi
}

# ─── 4. Backup Existing Config ───────────────────────────────────────────────
backup_config() {
  if [[ ! -d "$NVIM_CONFIG" ]]; then
    return 0
  fi

  # Idempotent: if sentinel exists, skip backup
  if [[ -f "$NVIM_CONFIG/$SENTINEL" ]]; then
    info "Managed config detected — skipping backup, updating in-place"
    return 0
  fi

  if $NO_BACKUP; then
    info "--no-backup: not backing up existing config"
    return 0
  fi

  local backup="${NVIM_CONFIG}.bak.${TIMESTAMP}"
  info "Backing up existing config to ${backup}"
  run mv "$NVIM_CONFIG" "$backup"
  success "Backup saved"
}

# ─── 5. Write Config Files ──────────────────────────────────────────────────
write_configs() {
  info "Creating directory structure"
  # Wipe managed source dirs so stale files from prior installs (e.g. a leftover
  # lua/plugins/init.lua that returns nil) can't break `require("lazy").setup`.
  run rm -rf "$NVIM_CONFIG/lua/core" "$NVIM_CONFIG/lua/plugins"
  run mkdir -p "$NVIM_CONFIG/lua/core"
  run mkdir -p "$NVIM_CONFIG/lua/plugins"

  # --- init.lua ---
  run tee "$NVIM_CONFIG/init.lua" >/dev/null <<'LUAEOF'
-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Set leader BEFORE loading plugins
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Load config modules
require("core.options")
require("core.keymaps")
require("core.autocmds")
require("lazy").setup("plugins")
LUAEOF

  # --- lua/core/options.lua ---
  run tee "$NVIM_CONFIG/lua/core/options.lua" >/dev/null <<'LUAEOF'
local opt = vim.opt
opt.number = true
opt.relativenumber = true
opt.tabstop = 2
opt.shiftwidth = 2
opt.expandtab = true
opt.smartindent = true
opt.wrap = false
opt.swapfile = false
opt.backup = false
opt.undofile = true
opt.hlsearch = true
opt.incsearch = true
opt.termguicolors = true
opt.scrolloff = 8
opt.sidescrolloff = 8
opt.signcolumn = "yes"
opt.isfname:append("@-@")
opt.updatetime = 50
opt.colorcolumn = "120"
opt.splitbelow = true
opt.splitright = true
opt.mouse = "a"
opt.clipboard = "unnamedplus"
opt.ignorecase = true
opt.smartcase = true
LUAEOF

  # --- lua/core/keymaps.lua ---
  run tee "$NVIM_CONFIG/lua/core/keymaps.lua" >/dev/null <<'LUAEOF'
-- Core keymaps (not plugin-specific; plugin keymaps live in their plugin specs)
local map = vim.keymap.set

-- Quality of Life
map("n", "<Esc><Esc>", "<Cmd>nohlsearch<CR>", { desc = "Clear search highlights" })
map("n", "<Leader>w", "<Cmd>write<CR>", { desc = "Save file" })
map("i", "jk", "<Esc>", { desc = "Escape insert mode" })

-- Buffer Management
map("n", "<Leader>bd", "<Cmd>bdelete<CR>", { desc = "Delete buffer" })
map("n", "<Tab>", "<Cmd>bnext<CR>", { desc = "Next buffer" })
map("n", "<S-Tab>", "<Cmd>bprevious<CR>", { desc = "Previous buffer" })

-- Window Splits
map("n", "<Leader>wv", "<Cmd>vsplit<CR>", { desc = "Vertical split" })
map("n", "<Leader>wh", "<Cmd>split<CR>", { desc = "Horizontal split" })
map("n", "<Leader>wq", "<Cmd>close<CR>", { desc = "Close window" })
map("n", "<C-h>", "<C-w>h", { desc = "Move to left window" })
map("n", "<C-j>", "<C-w>j", { desc = "Move to below window" })
map("n", "<C-k>", "<C-w>k", { desc = "Move to above window" })
map("n", "<C-l>", "<C-w>l", { desc = "Move to right window" })
LUAEOF

  # --- lua/core/autocmds.lua ---
  run tee "$NVIM_CONFIG/lua/core/autocmds.lua" >/dev/null <<'LUAEOF'
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

-- Auto-open nvim-tree when nvim is launched with a directory argument
vim.api.nvim_create_autocmd("VimEnter", {
  group = vim.api.nvim_create_augroup("NvimTreeDir", { clear = true }),
  callback = function(data)
    if data.file and vim.fn.isdirectory(data.file) == 1 then
      vim.cmd("NvimTreeOpen")
    end
  end,
})
LUAEOF

  # --- lua/plugins/treesitter.lua (branch chosen at runtime via vim.version) ---
  run tee "$NVIM_CONFIG/lua/plugins/treesitter.lua" >/dev/null <<'LUAEOF'
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
  -- main branch: configs module is gone; install parsers via the new API.
  -- Highlighting is enabled per-buffer by the FileType autocmd (vim.treesitter.start).
  config_fn = function()
    local ok, ts = pcall(require, "nvim-treesitter")
    if ok and type(ts.install) == "function" then
      ts.install({
        "lua", "python", "javascript", "typescript", "tsx",
        "bash", "json", "yaml", "toml",
        "markdown", "markdown_inline",
        "html", "css", "dockerfile", "sql", "rust",
      })
    end
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
LUAEOF

  # --- lua/plugins/nvim-tree.lua ---
  run tee "$NVIM_CONFIG/lua/plugins/nvim-tree.lua" >/dev/null <<'LUAEOF'
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
LUAEOF

  # --- lua/plugins/telescope.lua ---
  run tee "$NVIM_CONFIG/lua/plugins/telescope.lua" >/dev/null <<'LUAEOF'
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
LUAEOF

  # --- lua/plugins/which-key.lua ---
  run tee "$NVIM_CONFIG/lua/plugins/which-key.lua" >/dev/null <<'LUAEOF'
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
LUAEOF

  # --- lua/plugins/lualine.lua ---
  run tee "$NVIM_CONFIG/lua/plugins/lualine.lua" >/dev/null <<'LUAEOF'
return {
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    event = "VeryLazy",
    opts = {
      options = {
        theme = "catppuccin",
      },
      sections = {
        lualine_a = { "mode" },
        lualine_b = { "branch", "diff" },
        lualine_c = { { "filename", path = 1, symbols = { modified = " [+]", readonly = " [RO]" } } },
        lualine_x = { "diagnostics", "filetype" },
        lualine_y = { "location" },
        lualine_z = { "progress" },
      },
    },
  },
}
LUAEOF

  # --- lua/plugins/catppuccin.lua ---
  run tee "$NVIM_CONFIG/lua/plugins/catppuccin.lua" >/dev/null <<'LUAEOF'
return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    opts = {
      flavour = "macchiato",
      integrations = {
        nvimtree = true,
        telescope = true,
        which_key = true,
        lualine = true,
      },
    },
    config = function(_, opts)
      require("catppuccin").setup(opts)
      vim.cmd.colorscheme("catppuccin")
    end,
  },
}
LUAEOF

  # --- Sentinel ---
  run tee "$NVIM_CONFIG/$SENTINEL" >/dev/null <<'LUAEOF'
# This file marks the nvim config as managed by loom-vim.
# If present, the installer skips backup and overwrites files in-place.
LUAEOF

  success "Config files written to $NVIM_CONFIG"
}

# Run a headless nvim command, detecting errors by scanning output (since
# headless nvim exits 0 even when commands inside it error out).
# Args: <log-path> <pattern> <cmd> [<cmd>...]
#   <pattern> is the extended regex of failure markers; if any line matches,
#   run_headless returns non-zero.
run_headless() {
  local log="$1"; shift
  local pattern="$1"; shift
  local cmd_args=()
  for c in "$@"; do cmd_args+=("-c" "$c"); done
  cmd_args+=("-c" "qa!")
  nvim --headless "${cmd_args[@]}" >"$log" 2>&1 || true
  if grep -qE "$pattern" "$log"; then
    return 1
  fi
  return 0
}

# Failure markers. Plugin sync (`Lazy! sync`) intentionally excludes the
# nvim-treesitter per-parser `] error:` lines — those are a downstream symptom
# of a missing `tree-sitter` CLI and are surfaced by install_parsers, not here.
RX_FATAL='(^E[0-9]+:|^Error |Failed to|stack traceback)'
RX_PARSER='(^E[0-9]+:|^Error |Failed to|stack traceback|\] error:)'

# ─── 6. Bootstrap Lazy.nvim Plugins ─────────────────────────────────────────
bootstrap_lazy() {
  info "Installing plugins (headless Lazy sync)..."
  if $DRY_RUN; then
    printf "${BOLD}[DRY]${NC}   nvim --headless '+Lazy! sync' +qa\n"
    return 0
  fi
  local log=/tmp/loom-lazy-sync.log
  if run_headless "$log" "$RX_FATAL" "Lazy! sync"; then
    success "Plugin sync complete"
  else
    error "Plugin sync failed — see $log"
    error "Inspect interactively with: nvim +Lazy"
    exit 1
  fi
}

# ─── 7. Install Treesitter Parsers ──────────────────────────────────────────
install_parsers() {
  info "Installing treesitter parsers (synchronous)..."
  if $DRY_RUN; then
    printf "${BOLD}[DRY]${NC}   nvim --headless +<sync parser install> +qa\n"
    return 0
  fi

  # On the `main` branch (Neovim 0.12+), :TSUpdate is async and returns before
  # parsers finish compiling — we must use the install():wait() Lua API.
  # On `master` (Neovim 0.11), :TSUpdateSync is the synchronous variant.
  local lua_script=/tmp/loom-ts-install.lua
  cat >"$lua_script" <<'LUAEOF'
local langs = {
  "lua", "python", "javascript", "typescript", "tsx",
  "bash", "json", "yaml", "toml",
  "markdown", "markdown_inline",
  "html", "css", "dockerfile", "sql", "rust",
}
local ok, ts = pcall(require, "nvim-treesitter")
if ok and type(ts.install) == "function" then
  local task = ts.install(langs)
  if task and type(task.wait) == "function" then
    pcall(task.wait, task, 180000)
  end
else
  pcall(vim.cmd, "TSUpdateSync")
end
LUAEOF

  local log=/tmp/loom-tsupdate.log
  if run_headless "$log" "$RX_PARSER" "luafile $lua_script"; then
    success "Treesitter parsers installed"
  else
    warn "Treesitter parser install reported issues — see $log"
    if grep -qE "ENOENT.*tree-sitter|tree-sitter.*not found" "$log" 2>/dev/null; then
      warn "Root cause: \`tree-sitter\` CLI is missing or too old (need >= 0.26.1)."
      warn "Install via bootstrap.sh, or grab the binary from:"
      warn "  https://github.com/tree-sitter/tree-sitter/releases/latest"
    fi
    warn "Editor will work; treesitter highlighting kicks in once parsers compile."
  fi
}

# ─── 7b. Verify Install ─────────────────────────────────────────────────────
verify_install() {
  info "Verifying install (config loads cleanly)..."
  if $DRY_RUN; then
    printf "${BOLD}[DRY]${NC}   nvim --headless +qa\n"
    return 0
  fi
  local log=/tmp/loom-verify.log
  if run_headless "$log" "$RX_FATAL" "echo 'loom-vim ready'"; then
    success "Config loads cleanly"
  else
    warn "Startup produced errors — review: $log"
  fi
}

# ─── 8. Print Summary ───────────────────────────────────────────────────────
print_summary() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  printf "${GREEN}${BOLD}  ✓ loom-vim installed successfully!${NC}\n"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "  Config directory:  $NVIM_CONFIG"
  echo "  Leader key:        <Space>"
  echo ""
  echo "  Key bindings:"
  echo "    <Space>e         Toggle file tree"
  echo "    <Space>ff        Find files"
  echo "    <Space>fg        Live grep (find in files)"
  echo "    <Space>?         Show all keymaps (which-key)"
  echo ""
  echo "  First run:"
  echo "    $ nvim"
  echo ""
  echo "  Re-run this installer anytime — it's idempotent."
  echo ""
  echo "  Repository: https://github.com/claytantor/loom-vim"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# ─── Main ────────────────────────────────────────────────────────────────────
main() {
  local os
  os=$(detect_os)
  info "Detected OS: ${os}"

  local ts_branch
  ts_branch=$(check_nvim)

  check_deps "$ts_branch"
  backup_config
  write_configs
  bootstrap_lazy
  install_parsers
  verify_install
  print_summary
}

main "$@"