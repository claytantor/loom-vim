#!/usr/bin/env bash
set -euo pipefail

# loom-vim bootstrap — installs the latest Neovim, system dependencies, and the
# loom-vim configuration on most Linux distros (Debian/Ubuntu, Fedora/RHEL,
# Arch, openSUSE, Alpine). After packages are in place it chains to install.sh.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/claytantor/loom-vim/main/bootstrap.sh | bash
#   bash bootstrap.sh [--dry-run] [--no-backup] [--nightly]
#
# Env overrides:
#   LOOM_NVIM_RELEASE=stable|nightly   (default: stable)

REPO_RAW="https://raw.githubusercontent.com/claytantor/loom-vim/main"
NVIM_BIN="/usr/local/bin/nvim"
NVIM_RELEASE="${LOOM_NVIM_RELEASE:-stable}"
TREE_SITTER_MIN="0.26.0"
FORWARD_ARGS=()

for arg in "$@"; do
  case "$arg" in
    --nightly) NVIM_RELEASE="nightly" ;;
    --stable)  NVIM_RELEASE="stable" ;;
    --help|-h)
      cat <<EOF
loom-vim bootstrap

Installs Neovim ($NVIM_RELEASE), system dependencies, and loom-vim config.

Options:
  --stable     Install Neovim stable release (default)
  --nightly    Install Neovim nightly
  --dry-run    Forwarded to install.sh
  --no-backup  Forwarded to install.sh

Note: tree-sitter CLI is installed automatically whenever the resulting
      Neovim is >= 0.12 (current stable is already 0.12+).
EOF
      exit 0
      ;;
    *) FORWARD_ARGS+=("$arg") ;;
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

version_ge() {
  # version_ge A B → exit 0 if A >= B (using sort -V).
  printf '%s\n%s\n' "$2" "$1" | sort -V -C
}

# ─── Privilege Escalation ────────────────────────────────────────────────────
SUDO=""
if [[ "$EUID" -ne 0 ]]; then
  if command -v sudo &>/dev/null; then
    SUDO="sudo"
  else
    error "Root or sudo is required to install system packages."
    exit 1
  fi
fi

# ─── Distro Detection ────────────────────────────────────────────────────────
detect_distro() {
  if [[ ! -f /etc/os-release ]]; then
    error "Cannot detect distro: /etc/os-release is missing"
    exit 1
  fi
  # shellcheck disable=SC1091
  source /etc/os-release
  local id="${ID:-unknown}"
  local id_like="${ID_LIKE:-}"

  case "$id" in
    ubuntu|debian|linuxmint|pop|elementary|raspbian|kali|zorin) echo "debian"; return ;;
    fedora|rhel|centos|rocky|almalinux|ol|amzn)                 echo "rhel"; return ;;
    arch|manjaro|endeavouros|cachyos|garuda)                    echo "arch"; return ;;
    opensuse*|sles|sled)                                        echo "suse"; return ;;
    alpine)                                                     echo "alpine"; return ;;
  esac

  case "$id_like" in
    *debian*|*ubuntu*) echo "debian" ;;
    *rhel*|*fedora*)   echo "rhel" ;;
    *arch*)            echo "arch" ;;
    *suse*)            echo "suse" ;;
    *)                 echo "unknown" ;;
  esac
}

# ─── System Packages ─────────────────────────────────────────────────────────
install_packages() {
  local family="$1"
  info "Installing system packages for: ${family}"
  case "$family" in
    debian)
      $SUDO apt-get update -y
      $SUDO apt-get install -y --no-install-recommends \
        git curl ca-certificates ripgrep fd-find build-essential unzip fontconfig
      # Debian/Ubuntu ships `fd` as `fdfind`; provide an `fd` shim
      if ! command -v fd &>/dev/null && command -v fdfind &>/dev/null; then
        $SUDO ln -sf "$(command -v fdfind)" /usr/local/bin/fd
      fi
      ;;
    rhel)
      local pm
      if command -v dnf &>/dev/null; then pm=dnf
      elif command -v yum &>/dev/null; then pm=yum
      else error "No dnf/yum found"; exit 1
      fi
      $SUDO "$pm" install -y git curl ca-certificates ripgrep fd-find make gcc unzip fontconfig
      ;;
    arch)
      $SUDO pacman -Sy --noconfirm --needed git curl ca-certificates ripgrep fd make gcc unzip fontconfig
      ;;
    suse)
      $SUDO zypper --non-interactive install --no-recommends \
        git curl ca-certificates ripgrep fd make gcc unzip fontconfig
      ;;
    alpine)
      $SUDO apk add --no-cache git curl ca-certificates ripgrep fd make gcc musl-dev bash unzip fontconfig
      ;;
    *)
      error "Unsupported distro family. Install manually: git curl ripgrep fd make gcc"
      exit 1
      ;;
  esac
  success "System packages installed"
}

# ─── tree-sitter CLI ─────────────────────────────────────────────────────────
# Required by nvim-treesitter's `main` branch (Neovim 0.12+).
# Most distro packages are too old (e.g. Debian ships 0.20.x; we need >= 0.26.1),
# so prefer the official GitHub release binary and fall back to cargo.
# Detect the system's glibc version. Returns empty on non-glibc systems (musl).
glibc_version() {
  if command -v ldd &>/dev/null; then
    ldd --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+$' | head -n1
  fi
}

# Verify that a candidate tree-sitter binary actually runs on this system.
# The official Linux releases are dynamically linked against modern glibc, so
# on older distros (Ubuntu 22.04 / Debian 12 / RHEL 9) the prebuilt binary
# fails at load time with `GLIBC_2.XX not found`. Catch that before installing.
tree_sitter_binary_runs() {
  local bin="$1"
  local errfile
  errfile=$(mktemp)
  if "$bin" --version >/dev/null 2>"$errfile"; then
    rm -f "$errfile"
    return 0
  fi
  if grep -q 'GLIBC' "$errfile"; then
    warn "Prebuilt tree-sitter requires a newer glibc than this system has:"
    warn "  $(grep GLIBC "$errfile" | head -n1)"
    warn "  system glibc: $(glibc_version || echo unknown)"
  else
    warn "Prebuilt tree-sitter failed to run: $(head -n1 "$errfile")"
  fi
  rm -f "$errfile"
  return 1
}

install_tree_sitter_cli() {
  if command -v tree-sitter &>/dev/null; then
    local current
    current=$(tree-sitter --version 2>/dev/null | head -n1 | awk '{print $2}')
    if [[ -n "$current" ]] && version_ge "$current" "$TREE_SITTER_MIN"; then
      success "tree-sitter CLI ${current} already present"
      return 0
    fi
    warn "tree-sitter ${current:-unknown} found but < ${TREE_SITTER_MIN}; upgrading"
  fi

  local arch asset
  arch=$(uname -m)
  case "$arch" in
    x86_64|amd64)  asset="tree-sitter-linux-x64.gz" ;;
    aarch64|arm64) asset="tree-sitter-linux-arm64.gz" ;;
    *)
      warn "No tree-sitter prebuilt binary for ${arch}; building from source"
      build_tree_sitter_from_source
      return $?
      ;;
  esac

  info "Downloading tree-sitter CLI (latest release, ${arch})..."
  local tmp
  tmp=$(mktemp -d)
  local url="https://github.com/tree-sitter/tree-sitter/releases/latest/download/${asset}"
  if ! curl -fL --progress-bar -o "$tmp/ts.gz" "$url"; then
    warn "GitHub download failed — falling back to source build"
    rm -rf "$tmp"
    build_tree_sitter_from_source
    return $?
  fi
  gunzip -f "$tmp/ts.gz"
  chmod +x "$tmp/ts"

  # Make sure the binary actually runs on this system before installing it.
  if ! tree_sitter_binary_runs "$tmp/ts"; then
    warn "Falling back to a source build (cargo install)."
    rm -rf "$tmp"
    build_tree_sitter_from_source
    return $?
  fi

  $SUDO install -m 0755 "$tmp/ts" /usr/local/bin/tree-sitter
  rm -rf "$tmp"
  success "tree-sitter CLI installed: $(tree-sitter --version | head -n1)"
}

# Build tree-sitter-cli locally with cargo. Slower (~5 min on a typical
# laptop) but always works because it links against the local glibc.
# If cargo is missing, try to install it via the distro first, then rustup
# as a last resort.
build_tree_sitter_from_source() {
  if ! command -v cargo &>/dev/null; then
    info "cargo not found — trying to install Rust toolchain"
    if ! install_rust_toolchain; then
      error "Cannot build tree-sitter without a Rust toolchain."
      error "Install rustup manually (https://rustup.rs) and re-run bootstrap, or"
      error "download an older tree-sitter release that matches your glibc from:"
      error "  https://github.com/tree-sitter/tree-sitter/releases"
      return 1
    fi
  fi

  warn "Building tree-sitter-cli from source — this takes several minutes."
  if cargo install tree-sitter-cli --locked; then
    # cargo installs to ~/.cargo/bin; symlink into /usr/local/bin so nvim's
    # parser build step finds it without depending on PATH ordering.
    if [[ -x "$HOME/.cargo/bin/tree-sitter" ]]; then
      $SUDO ln -sf "$HOME/.cargo/bin/tree-sitter" /usr/local/bin/tree-sitter
    fi
    success "tree-sitter CLI built from source: $(tree-sitter --version | head -n1)"
    return 0
  fi
  error "cargo install tree-sitter-cli failed."
  return 1
}

# Best-effort install of a Rust toolchain. Prefers the distro's `cargo`
# package (faster, no extra moving parts), falls back to rustup.
install_rust_toolchain() {
  local installed_via=""
  if command -v apt-get &>/dev/null; then
    if $SUDO apt-get install -y cargo rustc 2>/dev/null; then installed_via=apt; fi
  elif command -v dnf &>/dev/null; then
    if $SUDO dnf install -y cargo rust 2>/dev/null; then installed_via=dnf; fi
  elif command -v pacman &>/dev/null; then
    if $SUDO pacman -Sy --noconfirm --needed rust 2>/dev/null; then installed_via=pacman; fi
  elif command -v zypper &>/dev/null; then
    if $SUDO zypper --non-interactive install cargo rust 2>/dev/null; then installed_via=zypper; fi
  elif command -v apk &>/dev/null; then
    if $SUDO apk add --no-cache cargo rust 2>/dev/null; then installed_via=apk; fi
  fi

  if [[ -z "$installed_via" ]]; then
    info "Distro cargo unavailable — falling back to rustup"
    curl -fsSL https://sh.rustup.rs | sh -s -- -y --default-toolchain stable --no-modify-path
    # rustup installs to ~/.cargo/bin which won't be on PATH in this shell
    export PATH="$HOME/.cargo/bin:$PATH"
  fi

  command -v cargo &>/dev/null
}

# ─── Nerd Font ───────────────────────────────────────────────────────────────
# nvim-tree, telescope, lualine, and which-key render icons from the
# private-use Unicode area. Without a Nerd Font installed in the terminal,
# these show as boxes with hex codepoints. Installs JetBrainsMono Nerd Font
# user-level (no sudo) to ~/.local/share/fonts/NerdFonts.
NERD_FONT_VERSION="v3.4.0"
NERD_FONT_FAMILY="JetBrainsMono"
NERD_FONT_DIR="$HOME/.local/share/fonts/NerdFonts"

# Authoritative check: does fontconfig resolve "<family> Nerd Font" to a file
# whose path actually contains that family name? `fc-match` always returns
# *something* (fontconfig's fallback chain), so we must verify the result
# really is the font we wanted, not a substitute.
nerd_font_resolves() {
  local family="$1"
  command -v fc-match &>/dev/null || return 1
  local match
  match=$(fc-match -f '%{file}\n' "${family} Nerd Font" 2>/dev/null) || return 1
  [[ -n "$match" && "$match" == *"${family}"* && "$match" == *"NerdFont"* ]]
}

install_nerd_font() {
  if nerd_font_resolves "$NERD_FONT_FAMILY"; then
    success "${NERD_FONT_FAMILY} Nerd Font already installed and resolvable"
    return 0
  fi

  # If fontconfig wasn't installed by install_packages (older distros / minimal
  # images), fall back gracefully — the editor still works, just without icons.
  if ! command -v fc-cache &>/dev/null; then
    warn "fontconfig (fc-cache) not found — skipping Nerd Font install"
    warn "Install fontconfig and re-run bootstrap, or get a Nerd Font manually:"
    warn "  https://www.nerdfonts.com/font-downloads"
    return 0
  fi
  if ! command -v unzip &>/dev/null; then
    warn "unzip not found — skipping Nerd Font install"
    return 0
  fi

  info "Installing ${NERD_FONT_FAMILY} Nerd Font (${NERD_FONT_VERSION}) to ${NERD_FONT_DIR}..."
  local url="https://github.com/ryanoasis/nerd-fonts/releases/download/${NERD_FONT_VERSION}/${NERD_FONT_FAMILY}.zip"
  local tmp
  tmp=$(mktemp -d)
  if ! curl -fL --progress-bar -o "$tmp/font.zip" "$url"; then
    warn "Nerd Font download failed — get one manually from https://www.nerdfonts.com"
    rm -rf "$tmp"
    return 0
  fi
  mkdir -p "$NERD_FONT_DIR/$NERD_FONT_FAMILY"
  if ! unzip -oq "$tmp/font.zip" -d "$NERD_FONT_DIR/$NERD_FONT_FAMILY"; then
    warn "Failed to unzip Nerd Font archive — leaving system untouched"
    rm -rf "$tmp"
    return 0
  fi
  rm -rf "$tmp"

  # Rebuild the user's font cache. `fc-cache -f` without args also works, but
  # passing the directory is faster and avoids touching the system cache.
  fc-cache -f "$HOME/.local/share/fonts" >/dev/null 2>&1 || true

  # Authoritative verification: refuse to claim success unless fc-match agrees.
  if nerd_font_resolves "$NERD_FONT_FAMILY"; then
    local resolved
    resolved=$(fc-match -f '%{file}\n' "${NERD_FONT_FAMILY} Nerd Font")
    success "Nerd Font installed → resolves to: ${resolved}"
  else
    warn "Nerd Font files written to ${NERD_FONT_DIR} but fc-match doesn't resolve them yet."
    warn "Try: fc-cache -fv ~/.local/share/fonts   then   fc-match \"${NERD_FONT_FAMILY} Nerd Font\""
  fi

  echo ""
  printf "${YELLOW}[!]${NC}  Set your terminal emulator's font to '${NERD_FONT_FAMILY} Nerd Font'\n"
  printf "${YELLOW}[!]${NC}  for nvim-tree/telescope/lualine icons to render. Fontconfig\n"
  printf "${YELLOW}[!]${NC}  knowing about the font is NOT the same as the terminal using it.\n"
  echo ""
}

# Does the currently-installed nvim need tree-sitter CLI? (true for >= 0.12)
nvim_needs_tree_sitter() {
  local nvim_cmd
  if [[ -x "$NVIM_BIN" ]]; then
    nvim_cmd="$NVIM_BIN"
  elif command -v nvim &>/dev/null; then
    nvim_cmd="$(command -v nvim)"
  else
    return 1
  fi
  local v major minor
  v=$("$nvim_cmd" --version 2>/dev/null | head -n1 | sed -E 's/^NVIM v?([0-9]+\.[0-9]+).*/\1/')
  IFS='.' read -r major minor <<< "$v"
  [[ -n "${major:-}" && -n "${minor:-}" ]] || return 1
  if [[ "$major" -gt 0 ]] || [[ "$minor" -ge 12 ]]; then
    return 0
  fi
  return 1
}

# ─── Neovim Install ──────────────────────────────────────────────────────────
nvim_version_ok() {
  command -v nvim &>/dev/null || return 1
  local v major minor
  v=$(nvim --version | head -n1 | sed -E 's/^NVIM v?([0-9]+\.[0-9]+).*/\1/')
  IFS='.' read -r major minor <<< "$v"
  [[ -n "${major:-}" && -n "${minor:-}" ]] || return 1
  if [[ "$major" -gt 0 ]] || [[ "$minor" -ge 11 ]]; then
    return 0
  fi
  return 1
}

install_neovim() {
  if [[ "$NVIM_RELEASE" == "stable" ]] && nvim_version_ok; then
    success "Neovim $(nvim --version | head -n1 | awk '{print $2}') already installed"
    return 0
  fi

  local arch asset
  arch=$(uname -m)
  case "$arch" in
    x86_64|amd64)  asset="nvim-linux-x86_64.appimage" ;;
    aarch64|arm64) asset="nvim-linux-arm64.appimage" ;;
    *) error "Unsupported architecture: $arch"; exit 1 ;;
  esac

  local url="https://github.com/neovim/neovim/releases/download/${NVIM_RELEASE}/${asset}"
  info "Downloading Neovim ${NVIM_RELEASE} (${arch})..."
  local tmp
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT

  if ! curl -fL --progress-bar -o "$tmp/nvim.appimage" "$url"; then
    error "Download failed: $url"
    exit 1
  fi
  chmod +x "$tmp/nvim.appimage"

  # Try to run AppImage directly; if FUSE is unavailable, extract it.
  if "$tmp/nvim.appimage" --version &>/dev/null; then
    $SUDO install -m 0755 "$tmp/nvim.appimage" "$NVIM_BIN"
  else
    info "FUSE not available — extracting AppImage to /opt/nvim"
    (cd "$tmp" && ./nvim.appimage --appimage-extract >/dev/null)
    $SUDO rm -rf /opt/nvim
    $SUDO mv "$tmp/squashfs-root" /opt/nvim
    $SUDO ln -sf /opt/nvim/AppRun "$NVIM_BIN"
  fi

  success "Neovim installed: $("$NVIM_BIN" --version | head -n1)"
}

# ─── Chain into install.sh ───────────────────────────────────────────────────
run_loom_install() {
  info "Running loom-vim config installer..."
  local local_install="$(dirname "$0")/install.sh"
  local use_local=false
  if [[ "$0" != "bash" && "$0" != "-bash" && -f "$local_install" ]]; then
    use_local=true
  fi

  if [[ ${#FORWARD_ARGS[@]} -gt 0 ]]; then
    if $use_local; then
      bash "$local_install" "${FORWARD_ARGS[@]}"
    else
      curl -fsSL "${REPO_RAW}/install.sh" | bash -s -- "${FORWARD_ARGS[@]}"
    fi
  else
    if $use_local; then
      bash "$local_install"
    else
      curl -fsSL "${REPO_RAW}/install.sh" | bash
    fi
  fi
}

# ─── Main ────────────────────────────────────────────────────────────────────
main() {
  echo ""
  printf "${BOLD}loom-vim bootstrap${NC} (Linux, Neovim ${NVIM_RELEASE})\n"
  echo ""

  local family
  family=$(detect_distro)
  info "Detected distro family: ${family}"

  install_packages "$family"
  install_neovim

  # tree-sitter CLI is needed whenever the deployed nvim is >= 0.12,
  # regardless of whether the user asked for --stable or --nightly.
  if nvim_needs_tree_sitter; then
    install_tree_sitter_cli
  else
    info "Neovim < 0.12 — skipping tree-sitter CLI (master branch ships prebuilt parsers)"
  fi

  install_nerd_font

  run_loom_install
}

main "$@"
