# loom-vim

A set of configs to turn Neovim into a remote IDE.

## Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/claytantor/loom-vim/main/install.sh | bash
```

Or with options:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/claytantor/loom-vim/main/install.sh) [--dry-run] [--no-backup]
```

- `--dry-run` — Print what would be done without making changes
- `--no-backup` — Skip backing up an existing `~/.config/nvim`

## System Dependencies

The installer will warn you if any are missing but will not auto-install them.

| Dependency | Purpose | macOS | Ubuntu/Debian |
|-----------|---------|-------|---------------|
| Neovim ≥ 0.11 | Editor | `brew install neovim` | `apt install neovim` or [AppImage](https://github.com/neovim/neovim/releases) |
| git | Plugin fetching | pre-installed | `apt install git` |
| ripgrep (`rg`) | Telescope live_grep | `brew install ripgrep` | `apt install ripgrep` |
| `fd` | Telescope find_files | `brew install fd` | `apt install fd-find` |
| `make` | Build telescope-fzf-native | `xcode-select --install` | `apt install build-essential` |
| `gcc` / `clang` | Treesitter parser compilation | `xcode-select --install` | `apt install build-essential` |
| Nerd Font | Icons rendering | [nerdfonts.com](https://www.nerdfonts.com) | [nerdfonts.com](https://www.nerdfonts.com) |

> **Note:** A C compiler is only required for Neovim 0.12+ (treesitter `main` branch). Neovim 0.11 uses the `master` branch with pre-compiled parsers.

## Keybindings

**Leader key:** `<Space>`

### Core Navigation

| Binding | Action |
|---------|--------|
| `<Space>e` | Toggle file tree (nvim-tree) |
| `<Space>ef` | Focus file tree |
| `<Space>er` | Refresh file tree |
| `<Space>?` | Show all keymaps (which-key) |

### Telescope / Find

| Binding | Action |
|---------|--------|
| `<Space>ff` | Find files in project |
| `<Space>fg` | Live grep (find in files, recursive) |
| `<Space>fw` | Grep word under cursor |
| `<Space>fb` | List open buffers |
| `<Space>fh` | Search help tags |
| `<Space>fk` | Search keymaps |
| `<Space>fr` | Recent files |
| `<Space>fc` | Find in current buffer |

### Buffer Management

| Binding | Action |
|---------|--------|
| `<Space>bd` | Delete current buffer |
| `<Tab>` | Next buffer |
| `<S-Tab>` | Previous buffer |

### Window Splits

| Binding | Action |
|---------|--------|
| `<Space>wv` | Vertical split |
| `<Space>wh` | Horizontal split |
| `<Space>wq` | Close window |
| `Ctrl+h/j/k/l` | Navigate between windows |

### Quality of Life

| Binding | Action |
|---------|--------|
| `Esc Esc` | Clear search highlights |
| `<Space>w` | Save file |
| `jk` | Escape insert mode |

## Plugin Stack

| Plugin | Purpose |
|--------|---------|
| [lazy.nvim](https://github.com/folke/lazy.nvim) | Plugin manager |
| [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) | Syntax highlighting |
| [nvim-tree.lua](https://github.com/nvim-tree/nvim-tree.lua) | File browser |
| [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) | Fuzzy finder |
| [which-key.nvim](https://github.com/folke/which-key.nvim) | Keybinding cheatsheet |
| [catppuccin](https://github.com/catppuccin/nvim) | Theme (Macchiato) |
| [lualine.nvim](https://github.com/nvim-lualine/lualine.nvim) | Status line |
| [nvim-web-devicons](https://github.com/nvim-tree/nvim-web-devicons) | File icons |

## Neovim Version Support

| Neovim | Treesitter Branch | Notes |
|--------|-------------------|-------|
| 0.11.x stable | `master` | Pre-compiled parsers — no C toolchain or tree-sitter CLI needed at runtime |
| 0.12.x nightly+ | `main` | Requires `tree-sitter-cli ≥ 0.26.1` and a C compiler |

The deployed `treesitter.lua` detects the running Neovim version via `vim.version()` and selects the branch on every startup, so upgrading Neovim does not require rerunning the installer.

## File Layout

The installer writes the following under `~/.config/nvim/`:

```
~/.config/nvim/
├── init.lua                  # Entry — bootstraps lazy.nvim, loads core
├── .nvim-ide-managed         # Sentinel: tells installer this is managed
└── lua/
    ├── core/
    │   ├── options.lua       # vim.opt settings
    │   ├── keymaps.lua       # Plugin-agnostic keybindings
    │   └── autocmds.lua      # FileType autocommands (treesitter, folds)
    └── plugins/
        ├── init.lua          # (auto-discovered by lazy.nvim)
        ├── treesitter.lua
        ├── nvim-tree.lua
        ├── telescope.lua     # Includes <Space>f… keymaps
        ├── which-key.lua
        ├── lualine.lua
        └── catppuccin.lua
```

## Idempotency

Re-running the installer is safe — if `~/.config/nvim/.nvim-ide-managed` exists, backup is skipped and files are overwritten in-place.

## Full Specification

See [requirements/NVIM_CONFIGS.md](requirements/NVIM_CONFIGS.md) for the complete requirements document.