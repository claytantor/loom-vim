#!/usr/bin/env bash
# Install RobotoMono Nerd Font user-level and (where applicable) point
# the active terminal emulator at the Mono variant, then restart its server
# so a fresh window does a fresh font lookup.
#
# Usage:
#   bash <(curl -fsSL https://raw.githubusercontent.com/claytantor/loom-vim/main/scripts/install-nerdfonts.sh)
#   bash scripts/install-nerdfonts.sh [--family <Name>] [--no-terminal-config]
#
# This is a focused subset of bootstrap.sh — use bootstrap.sh if you want the
# full Neovim + system-deps install. Use this when icons are the only problem.
set -euo pipefail

NERD_FONT_VERSION="v3.4.0"
NERD_FONT_FAMILY="RobotoMono"
NERD_FONT_DIR="$HOME/.local/share/fonts/NerdFonts"
CONFIGURE_TERMINAL=true

for arg in "$@"; do
  case "$arg" in
    --family) shift; NERD_FONT_FAMILY="${1:-RobotoMono}"; shift ;;
    --no-terminal-config) CONFIGURE_TERMINAL=false ;;
    --help|-h)
      cat <<EOF
Install a Nerd Font and configure your terminal to use it.

Options:
  --family <Name>          Nerd Font family to install (default: RobotoMono)
                           Other examples: JetBrainsMono, FiraCode, Hack, Iosevka, Meslo
  --no-terminal-config     Install fonts but don't touch terminal settings
EOF
      exit 0
      ;;
  esac
done

# ─── Helpers ─────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
info()    { printf "${CYAN}[INFO]${NC}  %s\n" "$1"; }
warn()    { printf "${YELLOW}[WARN]${NC}  %s\n" "$1"; }
success() { printf "${GREEN}[ OK ]${NC}  %s\n" "$1"; }
error()   { printf "${RED}[ERR]${NC}  %s\n" "$1" >&2; }

SUDO=""
if [[ "$EUID" -ne 0 ]] && command -v sudo &>/dev/null; then
  SUDO="sudo"
fi

# Authoritative: did fontconfig get pointed at the *actual* file we installed,
# or is it returning a substitute? `fc-match` always returns *something*.
nerd_font_resolves() {
  command -v fc-match &>/dev/null || return 1
  local match
  match=$(fc-match -f '%{file}\n' "${NERD_FONT_FAMILY} Nerd Font" 2>/dev/null) || return 1
  [[ -n "$match" && "$match" == *"${NERD_FONT_FAMILY}"* && "$match" == *"NerdFont"* ]]
}

# ─── 1. Prereqs ──────────────────────────────────────────────────────────────
ensure_prereqs() {
  local missing=()
  command -v unzip   &>/dev/null || missing+=("unzip")
  command -v fc-cache &>/dev/null || missing+=("fontconfig")

  if [[ ${#missing[@]} -eq 0 ]]; then
    return 0
  fi

  info "Installing prerequisites: ${missing[*]}"
  if [[ -f /etc/debian_version ]] || grep -qi 'ubuntu\|debian' /etc/os-release 2>/dev/null; then
    $SUDO apt-get update -y
    $SUDO apt-get install -y --no-install-recommends "${missing[@]}"
  elif command -v dnf &>/dev/null; then
    $SUDO dnf install -y "${missing[@]}"
  elif command -v yum &>/dev/null; then
    $SUDO yum install -y "${missing[@]}"
  elif command -v pacman &>/dev/null; then
    $SUDO pacman -Sy --noconfirm --needed "${missing[@]}"
  elif command -v zypper &>/dev/null; then
    $SUDO zypper --non-interactive install "${missing[@]}"
  elif command -v apk &>/dev/null; then
    $SUDO apk add --no-cache "${missing[@]}"
  elif command -v brew &>/dev/null; then
    brew install "${missing[@]}"
  else
    error "Can't auto-install: ${missing[*]}. Install them manually and re-run."
    exit 1
  fi
}

# ─── 2. Font install ─────────────────────────────────────────────────────────
install_font() {
  if nerd_font_resolves; then
    success "${NERD_FONT_FAMILY} Nerd Font already installed and resolvable"
    return 0
  fi

  info "Installing ${NERD_FONT_FAMILY} Nerd Font (${NERD_FONT_VERSION}) to ${NERD_FONT_DIR}..."
  local url="https://github.com/ryanoasis/nerd-fonts/releases/download/${NERD_FONT_VERSION}/${NERD_FONT_FAMILY}.zip"
  local tmp
  tmp=$(mktemp -d)

  if ! curl -fL --progress-bar -o "$tmp/font.zip" "$url"; then
    error "Download failed: $url"
    error "Check that the family name is right — list at https://www.nerdfonts.com/font-downloads"
    rm -rf "$tmp"
    exit 1
  fi
  mkdir -p "$NERD_FONT_DIR/$NERD_FONT_FAMILY"
  unzip -oq "$tmp/font.zip" -d "$NERD_FONT_DIR/$NERD_FONT_FAMILY"
  rm -rf "$tmp"
  fc-cache -f "$HOME/.local/share/fonts" >/dev/null 2>&1 || true

  if nerd_font_resolves; then
    success "Installed → $(fc-match -f '%{file}\n' "${NERD_FONT_FAMILY} Nerd Font")"
  else
    error "Font files written but fc-match still doesn't resolve them."
    error "Try: fc-cache -fv ~/.local/share/fonts"
    exit 1
  fi
}

# ─── 3. Terminal configuration ───────────────────────────────────────────────
configure_gnome_terminal() {
  command -v gsettings &>/dev/null || return 1
  local profile
  profile=$(gsettings get org.gnome.Terminal.ProfilesList default 2>/dev/null | tr -d "'" || true)
  [[ -n "$profile" ]] || return 1

  local schema="org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:${profile}/"
  local target="${NERD_FONT_FAMILY} Nerd Font Mono 12"
  local current
  current=$(gsettings get "$schema" font 2>/dev/null | tr -d "'" || true)

  if [[ "$current" == "$target" ]]; then
    success "GNOME Terminal already set to: $current"
    return 0
  fi

  info "Setting GNOME Terminal font: '$current' → '$target'"
  gsettings set "$schema" use-system-font false
  gsettings set "$schema" font "$target"
  success "GNOME Terminal font configured"

  # Restart the server so a fresh window does a fresh font lookup.
  if pgrep -x gnome-terminal-server >/dev/null 2>&1; then
    info "Restarting gnome-terminal-server (any open windows will need to be reopened)..."
    gnome-terminal --quit 2>/dev/null || true
    sleep 1
    (nohup gnome-terminal >/dev/null 2>&1 &) || true
  fi
  return 0
}

write_terminal_hint() {
  warn "Couldn't auto-configure your terminal — set its font manually to:"
  warn "  ${NERD_FONT_FAMILY} Nerd Font Mono"
  warn ""
  warn "Common settings:"
  warn "  Alacritty (~/.config/alacritty/alacritty.toml):"
  warn "    [font.normal]"
  warn "    family = \"${NERD_FONT_FAMILY} Nerd Font Mono\""
  warn "  Kitty (~/.config/kitty/kitty.conf):"
  warn "    font_family ${NERD_FONT_FAMILY} Nerd Font Mono"
  warn "  WezTerm (~/.config/wezterm/wezterm.lua):"
  warn "    config.font = wezterm.font(\"${NERD_FONT_FAMILY} Nerd Font Mono\")"
  warn "  VS Code terminal (settings.json):"
  warn "    \"terminal.integrated.fontFamily\": \"${NERD_FONT_FAMILY} Nerd Font Mono\""
}

# ─── 4. Final test ───────────────────────────────────────────────────────────
print_test() {
  echo ""
  printf "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
  printf "${BOLD}  Visual test — open a ${YELLOW}fresh${NC}${BOLD} terminal window and run:${NC}\n"
  printf "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
  echo ""
  echo "    echo -e \"\\ue612 \\uf115 \\ue7a8 \\uf489 \\uf015 \\uf07b\""
  echo ""
  echo "  You should see 6 distinct icons (file/folder/terminal/etc),"
  echo "  NOT 6 boxes with hex digits."
  echo ""
  if [[ -n "${TMUX:-}" ]]; then
    warn "You're inside tmux. tmux passes the terminal's font through, so the"
    warn "outer terminal must be set correctly. If icons still look wrong after"
    warn "reopening the OUTER terminal, detach + reattach tmux."
  fi
}

# ─── Main ────────────────────────────────────────────────────────────────────
main() {
  echo ""
  printf "${BOLD}Nerd Font installer${NC} — ${NERD_FONT_FAMILY} ${NERD_FONT_VERSION}\n"
  echo ""

  ensure_prereqs
  install_font

  if $CONFIGURE_TERMINAL; then
    if ! configure_gnome_terminal; then
      write_terminal_hint
    fi
  else
    info "--no-terminal-config: leaving terminal settings untouched"
  fi

  print_test
}

main "$@"
