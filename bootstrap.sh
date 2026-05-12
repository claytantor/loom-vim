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
  --nightly    Install Neovim nightly (also installs tree-sitter CLI)
  --dry-run    Forwarded to install.sh
  --no-backup  Forwarded to install.sh
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
        git curl ca-certificates ripgrep fd-find build-essential unzip
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
      $SUDO "$pm" install -y git curl ca-certificates ripgrep fd-find make gcc unzip
      ;;
    arch)
      $SUDO pacman -Sy --noconfirm --needed git curl ca-certificates ripgrep fd make gcc unzip
      ;;
    suse)
      $SUDO zypper --non-interactive install --no-recommends \
        git curl ca-certificates ripgrep fd make gcc unzip
      ;;
    alpine)
      $SUDO apk add --no-cache git curl ca-certificates ripgrep fd make gcc musl-dev bash unzip
      ;;
    *)
      error "Unsupported distro family. Install manually: git curl ripgrep fd make gcc"
      exit 1
      ;;
  esac
  success "System packages installed"
}

# Optional: tree-sitter CLI (only required for nightly / treesitter `main` branch)
install_tree_sitter_cli() {
  local family="$1"
  if command -v tree-sitter &>/dev/null; then
    success "tree-sitter CLI already present"
    return 0
  fi
  info "Installing tree-sitter CLI (required for Neovim 0.12+ / nightly)..."
  case "$family" in
    debian)
      # Not in Debian stable repos; try apt first, fall back to cargo.
      if ! $SUDO apt-get install -y tree-sitter-cli 2>/dev/null; then
        warn "apt has no tree-sitter-cli; falling back to cargo"
        cargo_install_tree_sitter
      fi
      ;;
    rhel)
      local pm
      if command -v dnf &>/dev/null; then pm=dnf; else pm=yum; fi
      if ! $SUDO "$pm" install -y tree-sitter-cli 2>/dev/null; then
        cargo_install_tree_sitter
      fi
      ;;
    arch)
      $SUDO pacman -S --noconfirm --needed tree-sitter-cli
      ;;
    suse)
      $SUDO zypper --non-interactive install tree-sitter || cargo_install_tree_sitter
      ;;
    alpine)
      $SUDO apk add --no-cache tree-sitter || cargo_install_tree_sitter
      ;;
    *) cargo_install_tree_sitter ;;
  esac
}

cargo_install_tree_sitter() {
  if ! command -v cargo &>/dev/null; then
    warn "cargo is not installed; skipping tree-sitter CLI."
    warn "Install rustup (https://rustup.rs) and run: cargo install tree-sitter-cli"
    return 0
  fi
  cargo install tree-sitter-cli
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

  if [[ "$NVIM_RELEASE" == "nightly" ]]; then
    install_tree_sitter_cli "$family"
  fi

  install_neovim
  run_loom_install
}

main "$@"
