# Requirements: Neovim IDE Configuration — Agent Implementation Guide

**Version:** 1.0  
**Author:** Clay (DeepOrb Labs)  
**Target:** Agentic installer — single-line bootstrap from GitHub (`claytantor/loom-vim`)
**Neovim Minimum:** 0.11 stable (or 0.12 nightly for treesitter `main` branch)

---

## Critical: nvim-treesitter Compatibility Warning

The `nvim-treesitter/nvim-treesitter` repository was **archived on April 3, 2026** and is now read-only. The `main` branch requires **Neovim 0.12.0 nightly**. For Neovim 0.11 stable, the `master` branch must be used. The installer must detect the Neovim version and pin accordingly.

```
nvim --version   →  0.11.x  →  use branch = "master"
nvim --version   →  0.12.x  →  use branch = "main" (or omit for default)
```

---

## 1. Goals and Feature Requirements

| # | Feature | Implementation |
|---|---------|---------------|
| 1 | **Keybinding cheatsheet** — searchable, always-accessible popup of all custom bindings | `which-key.nvim` with group labels |
| 2 | **File browser/tree** — sidebar tree view, project-aware, git status icons | `nvim-tree.lua` |
| 3 | **Find in files (recursive)** — fuzzy search across all project files and content | `telescope.nvim` + `ripgrep` |
| 4 | **Syntax highlighting** — treesitter-powered for all supported languages | `nvim-treesitter` |
| 5 | **Plugin manager** — lazy-loading, lockfile, single source of truth | `lazy.nvim` |
| 6 | **Theme** — dark, modern, Catppuccin Macchiato | `catppuccin/nvim` |
| 7 | **Status line** — shows mode, git branch, LSP errors, file info | `lualine.nvim` |
| 8 | **Icons** — file-type icons in tree + telescope + statusline | `nvim-web-devicons` |

---

## 2. Plugin Stack

### 2.1 Plugin Manager — `lazy.nvim`

- **Repo:** `folke/lazy.nvim`
- **Bootstrap:** Self-bootstraps if not present (standard lazy.nvim bootstrap snippet)
- **Config location:** `~/.config/nvim/lua/plugins/init.lua`

### 2.2 Syntax — `nvim-treesitter`

- **Repo:** `nvim-treesitter/nvim-treesitter`
- **Branch:** Detect at install time (see §1 warning above)
- **Build step:** `:TSUpdate` — must be set as the `build` spec in lazy
- **`lazy = false`** — treesitter MUST NOT be lazy-loaded (plugin requirement)
- **Languages to auto-install:**
  ```
  lua, python, javascript, typescript, tsx, bash, json, yaml, toml,
  markdown, markdown_inline, html, css, dockerfile, sql, rust
  ```
- **Features to enable via `FileType` autocommand:**
  - Highlighting: `vim.treesitter.start()`
  - Folding:
    ```lua
    vim.wo[0][0].foldexpr = 'v:lua.vim.treesitter.foldexpr()'
    vim.wo[0][0].foldmethod = 'expr'
    vim.wo[0][0].foldenable = false   -- open all folds by default
    ```
  - Indentation: `vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"`

### 2.3 File Tree — `nvim-tree.lua`

- **Repo:** `nvim-tree/nvim-tree.lua`
- **Dependencies:** `nvim-tree/nvim-web-devicons`
- **Key settings:**
  ```lua
  disable_netrw = true,
  hijack_netrw = true,
  view = { width = 32, side = "left" },
  renderer = {
    group_empty = true,
    icons = { show = { git = true, file = true, folder = true } }
  },
  filters = { dotfiles = false },
  git = { enable = true }
  ```
- **Auto-open behavior:** Open nvim-tree when nvim is launched with a directory argument

### 2.4 Fuzzy Finder — `telescope.nvim`

- **Repo:** `nvim-telescope/telescope.nvim`
- **Dependencies:**
  - `nvim-lua/plenary.nvim`
  - `nvim-telescope/telescope-fzf-native.nvim` (requires `make` at build time)
- **System dependency:** `ripgrep` must be installed (see §5)
- **Key pickers to configure:**
  - `find_files` — project file search (respects `.gitignore`)
  - `live_grep` — recursive content search via ripgrep
  - `grep_string` — search word under cursor
  - `buffers` — open buffer list
  - `help_tags` — Neovim documentation search
  - `keymaps` — searchable keymap list (bridges to which-key)
- **Default settings:**
  ```lua
  defaults = {
    layout_strategy = "horizontal",
    layout_config = { preview_width = 0.55 },
    path_display = { "truncate" },
    file_ignore_patterns = { "node_modules", ".git/", "dist/", "__pycache__" }
  }
  ```

### 2.5 Keybinding Cheatsheet — `which-key.nvim`

- **Repo:** `folke/which-key.nvim`
- **Behavior:** Popup appears after a configurable timeout (default: 500ms) when a prefix key is held
- **Groups to register:**

  | Prefix | Group Label |
  |--------|-------------|
  | `<leader>f` | Find (Telescope) |
  | `<leader>e` | Explorer (nvim-tree) |
  | `<leader>b` | Buffers |
  | `<leader>g` | Git |
  | `<leader>l` | LSP |
  | `<leader>w` | Windows/splits |
  | `<leader>?` | Show all keymaps |

### 2.6 Theme — `catppuccin`

- **Repo:** `catppuccin/nvim`
- **Flavor:** `macchiato` (dark, high contrast)
- **Integrations to enable:** `nvim_tree`, `telescope`, `which_key`, `lualine`
- **Apply via:** `vim.cmd.colorscheme("catppuccin")`

### 2.7 Status Line — `lualine.nvim`

- **Repo:** `nvim-lualine/lualine.nvim`
- **Theme:** `catppuccin`
- **Sections:**
  - Left: mode, git branch, git diff stats
  - Center: filename + modified flag
  - Right: LSP diagnostics, filetype, line:col, progress

---

## 3. Keybindings Specification

**Leader key:** `<Space>`

Keybindings are split by ownership so lazy.nvim can defer plugin loading:

- **Plugin-agnostic bindings** (QoL, buffers, windows, save, escape) live in `~/.config/nvim/lua/core/keymaps.lua`.
- **Plugin-specific bindings** live in each plugin's `keys = { … }` table in its spec under `lua/plugins/`. This lets lazy.nvim load the plugin on first key press instead of at startup.

All bindings carry a `desc` field so which-key picks them up automatically for cheatsheet display.

### 3.1 Core Navigation

| Binding | Action |
|---------|--------|
| `<leader>e` | Toggle file tree (nvim-tree) |
| `<leader>ef` | Focus file tree |
| `<leader>er` | Refresh file tree |
| `<leader>?` | Open which-key cheatsheet (all bindings) |

### 3.2 Telescope / Find

| Binding | Action |
|---------|--------|
| `<leader>ff` | Find files in project |
| `<leader>fg` | Live grep (find in files, recursive) |
| `<leader>fw` | Grep word under cursor |
| `<leader>fb` | List open buffers |
| `<leader>fh` | Search help tags |
| `<leader>fk` | Search keymaps |
| `<leader>fr` | Recent files |
| `<leader>fc` | Find in current buffer |

### 3.3 Buffer Management

| Binding | Action |
|---------|--------|
| `<leader>bd` | Delete current buffer |
| `<Tab>` | Next buffer |
| `<S-Tab>` | Previous buffer |

### 3.4 Window Splits

| Binding | Action |
|---------|--------|
| `<leader>wv` | Vertical split |
| `<leader>wh` | Horizontal split |
| `<leader>wq` | Close window |
| `<C-h/j/k/l>` | Navigate between windows |

### 3.5 Quality of Life

| Binding | Action |
|---------|--------|
| `<Esc><Esc>` | Clear search highlights |
| `<leader>w` | Save file (normal mode) |
| `jk` | Escape insert mode |

---

## 4. File Structure

The agent must create the following directory/file layout:

```
~/.config/nvim/
├── init.lua                        # Entry point — bootstraps lazy.nvim, loads core
├── lua/
│   ├── core/
│   │   ├── options.lua             # vim.opt settings (tabs, line numbers, etc.)
│   │   ├── keymaps.lua             # All custom keybindings
│   │   └── autocmds.lua            # FileType autocommands (treesitter, folds)
│   └── plugins/
│       ├── treesitter.lua          # nvim-treesitter config
│       ├── treesitter.lua          # nvim-treesitter config
│       ├── nvim-tree.lua           # File tree config
│       ├── telescope.lua           # Telescope config + keymaps
│       ├── which-key.lua           # Which-key group registrations
│       ├── lualine.lua             # Status line config
│       └── catppuccin.lua          # Theme config
```

### 4.1 `init.lua` — Top-level entry

```lua
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
require("lazy").setup({ import = "plugins" })
```

### 4.2 `core/options.lua` — Sensible defaults

```lua
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
```

---

## 5. System Dependencies

The installer script must check for and install (or warn about) the following:

| Dependency | Purpose | Install (macOS) | Install (Ubuntu/Debian) |
|-----------|---------|-----------------|------------------------|
| `neovim >= 0.11` | Editor | `brew install neovim` | `apt install neovim` or AppImage |
| `git` | Plugin fetching | pre-installed | `apt install git` |
| `ripgrep` | Telescope live_grep backend | `brew install ripgrep` | `apt install ripgrep` |
| `fd` | Telescope find_files backend | `brew install fd` | `apt install fd-find` |
| `make` | Build telescope-fzf-native | `xcode-select --install` | `apt install build-essential` |
| `tree-sitter-cli >= 0.26.1` | Parser compilation (nvim-treesitter main only) | `brew install tree-sitter` | cargo/pkg manager |
| `gcc` or `clang` | C compiler for parsers | `xcode-select --install` | `apt install build-essential` |
| `node / npm` | Optional: many LSP servers | `brew install node` | `apt install nodejs` |
| `nerd font` | Icons rendering | Manual: nerdfonts.com | Manual: nerdfonts.com |

> **Note:** `tree-sitter-cli` and a C compiler are only required if using the `main` branch (Neovim 0.12+). The `master` branch ships pre-compiled parsers.

---

## 6. Installer Script Requirements

### 6.1 One-liner Interface

The installer must be invocable as:

```bash
curl -fsSL https://raw.githubusercontent.com/claytantor/loom-vim/main/install.sh | bash
```

Or with options:
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/claytantor/loom-vim/main/install.sh) [--dry-run] [--no-backup]
```

### 6.2 Installer Script Behavior (ordered steps)

1. **Detect OS** — macOS vs Linux (Debian/Ubuntu assumed for Linux)
2. **Check Neovim version** — parse `nvim --version`, extract semver, determine treesitter branch
3. **Backup existing config** — if `~/.config/nvim` exists, move to `~/.config/nvim.bak.<timestamp>`; skip with `--no-backup`
4. **Check system deps** — verify `git`, `ripgrep`, `fd`, `make`, `gcc`; print warnings for missing ones (do NOT auto-install system packages — just warn)
5. **Create directory structure** — `mkdir -p` all required dirs under `~/.config/nvim`
6. **Write config files** — create all `.lua` files listed in §4; embed file contents in the install script (heredoc or base64 encoded)
7. **First-run bootstrap** — execute `nvim --headless "+Lazy! sync" +qa` to install all plugins non-interactively
8. **Install treesitter parsers** — execute `nvim --headless "+TSUpdateSync" +qa`
9. **Print success summary** — list what was installed, any warnings, and first-run instructions

### 6.3 Script Structure

```bash
#!/usr/bin/env bash
set -euo pipefail

# --- Config ---
REPO_RAW="https://raw.githubusercontent.com/claytantor/loom-vim/main"
NVIM_CONFIG="$HOME/.config/nvim"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# --- Functions ---
detect_os()       { ... }
check_nvim()      { ... }   # returns version string
check_deps()      { ... }   # warns on missing deps
backup_config()   { ... }
write_configs()   { ... }   # writes all lua files via heredocs
bootstrap_lazy()  { ... }   # nvim --headless sync
install_parsers() { ... }   # nvim --headless TSUpdateSync
print_summary()   { ... }

# --- Main ---
main() {
  detect_os
  NVIM_VERSION=$(check_nvim)
  check_deps
  backup_config
  write_configs "$NVIM_VERSION"
  bootstrap_lazy
  install_parsers
  print_summary
}

main "$@"
```

### 6.4 Idempotency

Running the installer twice on an already-configured system must be safe. If `~/.config/nvim` already exists and looks like this config (check for sentinel file `.nvim-ide-managed`), skip backup and overwrite files in-place.

---

## 7. Repository Layout

The **[claytantor/loom-vim](https://github.com/claytantor/loom-vim)** repository must contain the following layout:

```
loom-vim/
├── install.sh              # Single-line installer (§6)
├── README.md               # Usage, screenshots, keybindings table
├── requirements/
│   └── NVIM_CONFIGS.md      # This requirements document
├── nvim/                   # Config source files (mirrored by installer)
│   ├── init.lua
│   └── lua/
│       ├── core/
│       └── plugins/
└── .nvim-ide-managed       # Sentinel file to detect managed installs
```

- The `install.sh` must either embed file contents directly OR `curl` each file from `nvim/` in the repo
- All files must be on the `main` branch
- The repo must be **public** for the one-liner to work without auth
- The installer URL is: `https://raw.githubusercontent.com/claytantor/loom-vim/main/install.sh`

---

## 8. Acceptance Criteria

The implementation is complete when all of the following pass:

- [ ] `curl ... | bash` runs to completion with no fatal errors on a clean macOS or Ubuntu system
- [ ] Neovim opens without errors (`nvim --headless "+checkhealth" +qa` exits 0)
- [ ] `<leader>e` toggles the file tree
- [ ] `<leader>ff` opens telescope file picker
- [ ] `<leader>fg` opens telescope live grep (recursive find in files)
- [ ] `<leader>?` or holding `<Space>` shows which-key popup with all registered groups
- [ ] Catppuccin Macchiato theme is applied
- [ ] Lualine status bar renders at bottom
- [ ] Treesitter highlighting is active for `.lua`, `.py`, `.js`, `.ts`, `.json` files
- [ ] Re-running installer is safe (idempotent, no duplicate backup)
- [ ] Works on Neovim 0.11 stable (treesitter `master` branch) AND 0.12 nightly (`main` branch)

---

## 9. Out of Scope (for this phase)

The following are explicitly excluded from this implementation:

- LSP / mason.nvim (planned for phase 2)
- Git integration (gitsigns, lazygit, neogit)
- Autocompletion (nvim-cmp, blink.cmp)
- Copilot / AI assistant plugins
- DAP (debug adapter protocol)
- Tab/buffer line plugin (bufferline)

---

## 10. References

| Resource | URL |
|---------|-----|
| nvim-treesitter (archived main) | https://github.com/nvim-treesitter/nvim-treesitter |
| lazy.nvim | https://github.com/folke/lazy.nvim |
| nvim-tree | https://github.com/nvim-tree/nvim-tree.lua |
| telescope.nvim | https://github.com/nvim-telescope/telescope.nvim |
| which-key.nvim | https://github.com/folke/which-key.nvim |
| catppuccin | https://github.com/catppuccin/nvim |
| lualine | https://github.com/nvim-lualine/lualine.nvim |
| ripgrep | https://github.com/BurntSushi/ripgrep |
| Nerd Fonts | https://www.nerdfonts.com/font-downloads |
