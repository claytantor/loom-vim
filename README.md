# loom-vim

A set of configs to turn Neovim into a remote IDE.

## Quick Install

**Start from scratch on a fresh Linux box** (installs latest Neovim + system deps, then the config):

```bash
curl -fsSL https://raw.githubusercontent.com/claytantor/loom-vim/main/bootstrap.sh | bash
```

Works on Debian/Ubuntu, Fedora/RHEL/CentOS, Arch, openSUSE, and Alpine. Uses `sudo` for package installs. Pass `--nightly` to install Neovim nightly + `tree-sitter-cli` instead of stable.

**Already have Neovim ≥ 0.11** (install just the loom-vim config):

```bash
curl -fsSL https://raw.githubusercontent.com/claytantor/loom-vim/main/install.sh | bash
```

Options (accepted by both scripts):

- `--dry-run` — Print what would be done without making changes
- `--no-backup` — Skip backing up an existing `~/.config/nvim`
- `--nightly` — *(bootstrap.sh only)* install Neovim nightly instead of stable

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

### Verify Nerd Fonts

After installing a Nerd Font, verify your terminal is configured correctly:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/claytantor/loom-vim/main/scripts/verify-nerdfonts.sh)
```

This checks font files, fontconfig registration, and terminal configuration. The installer also runs this check automatically.

## Keybindings

**Leader key:** `<Space>`

> **Tip:** Type `:cheat` inside neovim to open a scrollable cheat sheet of all key bindings. Press `q` or `Esc` to close it.

### Core Navigation

| Binding | Action |
|---------|--------|
| `<Space>e` | Toggle file tree (nvim-tree) |
| `<Space>ee` | Open file tree, close empty buffer |
| `<Space>ef` | Focus file tree |
| `<Space>er` | Refresh file tree |
| `<Space>?` | Show all keymaps (which-key) |

### SSH Behavior

When connected over SSH (or when `$DISPLAY` is unset), loom-vim automatically adjusts two settings:

**Mouse is disabled** — neovim stops capturing mouse events, so GNOME Terminal's native click-drag selection works exactly as it does with naked `vi` or `nano`. Select text by clicking and dragging, then copy with `Ctrl+Shift+C` or paste with middle-click. No tmux required.

**Clipboard uses OSC 52** — yanking in neovim (`"+y`) tunnels the clipboard through the terminal escape sequence directly to your local machine's clipboard, without needing `xclip`, `xsel`, or X11 forwarding.

Locally (with `$DISPLAY` set), mouse support and `xclip`/`xsel` clipboard are restored automatically.

### Opening Files in nano (SSH / no tmux)

When connected over SSH, copy-paste works without tmux by opening files in **nano** directly from the file tree. nano uses the terminal's native clipboard (`Ctrl+Shift+C` / `Ctrl+Shift+V` in GNOME Terminal), bypassing Neovim's clipboard entirely.

With the file tree focused, press `n` on any file to open it in nano in a split window to the right:

| Binding | Action |
|---------|--------|
| `n` *(in file tree)* | Open selected file in nano |
| `Ctrl+X` | Exit nano (closes the split) |
| `Ctrl+\` then `Ctrl+n` | Return to Neovim normal mode from any terminal split |

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
