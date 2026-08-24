#!/usr/bin/env bash
# YoRHa OS theme switcher.
#
# Usage: scripts/set-theme.sh light|dark
#
# Copies the chosen mode's colors.css to the single canonical path that every
# surface (Waybar, etc.) @imports, so switching modes swaps one file and nothing
# else changes. See docs/visual-identity.md ("Theming Modes").
#
# The destination defaults to ~/.config/yorha/colors.css and can be overridden
# with the YORHA_COLORS environment variable.
#
# Note: the wallpaper-derived ("dynamic") mode is intentionally NOT handled here
# — wallust writes the canonical file directly when that mode is enabled.
set -euo pipefail

mode="${1:-}"
case "$mode" in
  light|dark) ;;
  *)
    echo "Usage: $(basename "$0") light|dark" >&2
    exit 2
    ;;
esac

# Repo root = parent of this script's directory, so the script works regardless
# of the caller's working directory.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"

src="$repo_root/themes/$mode/colors.css"
dest="${YORHA_COLORS:-$HOME/.config/yorha/colors.css}"

if [[ ! -f "$src" ]]; then
  echo "error: theme file not found: $src" >&2
  exit 1
fi

mkdir -p "$(dirname "$dest")"
cp -- "$src" "$dest"
echo "Theme set to '$mode' -> $dest"
