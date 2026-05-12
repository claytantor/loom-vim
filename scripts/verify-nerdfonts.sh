#!/usr/bin/env bash
# Verify Nerd Fonts are correctly installed and usable
# Usage: bash scripts/verify-nerdfonts.sh
set -euo pipefail

PASS=0
FAIL=0

check() {
  local label="$1" result="$2"
  if [ "$result" = "ok" ]; then
    printf "  \033[0;32m✓\033[0m %s\n" "$label"
    PASS=$((PASS + 1))
  else
    printf "  \033[0;31m✗\033[0m %s\n" "$label"
    FAIL=$((FAIL + 1))
  fi
}

warn() {
  printf "  \033[1;33m⚠\033[0m %s\n" "$1"
}

NF="JetBrainsMono Nerd Font"

echo ""
echo "Nerd Font Verification"
echo "======================"

# ─── 1. Font files on disk ──────────────────────────────────────────────────
echo ""
echo "1. Font files"
font_files=$(find ~/.local/share/fonts /usr/share/fonts -iname '*nerd*' -name '*.ttf' 2>/dev/null || true)
if [ -n "$font_files" ]; then
  count=$(echo "$font_files" | wc -l)
  family=$(echo "$font_files" | head -1 | sed 's|.*/NerdFonts/||; s|/.*||')
  check "Nerd Font .ttf files found ($count — $family)" "ok"
else
  check "Nerd Font .ttf files found" "fail"
  echo "    Install with: brew install --cask font-jetbrains-mono-nerd-font"
  echo "    Or:           mkdir -p ~/.local/share/fonts && cd ~/.local/share/fonts"
  echo "                  curl -fLO https://github.com/ryanoasis/nerd-fonts/raw/master/patchedFonts/JetBrainsMono/JetBrainsMonoNerdFont-Regular.ttf"
fi

# ─── 2. Fontconfig registration ─────────────────────────────────────────────
echo ""
echo "2. Fontconfig registration"
_nf_fc_tmp=$(mktemp); fc-list > "$_nf_fc_tmp" 2>/dev/null
if grep -qi "nerd font" "$_nf_fc_tmp"; then
  family=$(grep -i "nerd font" "$_nf_fc_tmp" | head -1 | sed 's/.*: //' | cut -d, -f1 | xargs)
  check "Fontconfig has: $family" "ok"
else
  check "Fontconfig has Nerd Font entries" "fail"
  echo "    Fix: fc-cache -fv"
fi
rm -f "$_nf_fc_tmp"

# ─── 3. Terminal font configuration ─────────────────────────────────────────
echo ""
echo "3. Terminal font configuration"
if command -v gsettings &>/dev/null; then
  profile=$(gsettings get org.gnome.Terminal.ProfilesList default 2>/dev/null | tr -d "'" || true)
  if [ -n "$profile" ]; then
    term_font=$(gsettings get org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:${profile}/ font 2>/dev/null | tr -d "'" || true)
    use_sys=$(gsettings get org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:${profile}/ use-system-font 2>/dev/null || true)
    if echo "$term_font" | grep -qi "nerd"; then
      check "GNOME Terminal font: $term_font" "ok"
    elif [ "$use_sys" = "true" ]; then
      sys_mono=$(fc-match Monospace 2>/dev/null | cut -d: -f1 | xargs || echo "unknown")
      check "GNOME Terminal uses system font → $sys_mono" "fail"
      echo "    Fix:"
      echo "      gsettings set org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:${profile}/ use-system-font false"
      echo "      gsettings set org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:${profile}/ font '$NF 12'"
    else
      check "GNOME Terminal font: $term_font" "fail"
      echo "    Fix: gsettings set org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:${profile}/ font '$NF 12'"
    fi
  fi
elif [ -f ~/.config/alacritty/alacritty.toml ]; then
  if grep -qi "JetBrains\|Nerd" ~/.config/alacritty/alacritty.toml; then
    check "Alacritty configured with Nerd Font" "ok"
  else
    check "Alacritty not using a Nerd Font" "fail"
    echo "    Fix: add 'family = \"$NF\"' to [font.normal] in alacritty.toml"
  fi
elif [ -f ~/.config/kitty/kitty.conf ]; then
  if grep -qi "JetBrains\|Nerd" ~/.config/kitty/kitty.conf; then
    check "Kitty configured with Nerd Font" "ok"
  else
    check "Kitty not using a Nerd Font" "fail"
    echo "    Fix: add 'font_family $NF' to kitty.conf"
  fi
else
  warn "Can't auto-detect terminal — verify manually that your terminal is set to a Nerd Font"
fi

# ─── 4. Icon rendering test ─────────────────────────────────────────────────
echo ""
echo "4. Icon rendering (visual check)"
echo "   You should see distinct symbols below, NOT boxes □ or blanks:"
echo ""
echo -e "     \ue612  \uf115  \ue7a8  \uf489  \uf015  \uf013  \uf419  \uf07b  \uf410"
echo ""
echo "   If you see boxes, your terminal is NOT rendering Nerd Font glyphs."

# ─── Summary ────────────────────────────────────────────────────────────────
echo ""
echo "======================"
if [ "$FAIL" -eq 0 ]; then
  printf "\033[0;32m✓ All %d checks passed\033[0m\n" "$PASS"
else
  printf "\033[0;31m✗ %d check(s) failed, %d passed\033[0m\n" "$FAIL" "$PASS"
  exit 1
fi