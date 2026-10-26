#!/usr/bin/env bash
# Pull the latest from GitHub for the branch you're on and apply it.
#
#   ~/yorha-os/scripts/sync.sh
#
# Works on both setups:
#   aki/daily  -> Hyprland + DankMaterialShell (glass), kitty, helper scripts
#   other      -> Hyprland + yorha-bar (the YoRHa OS work)
# Existing configs are kept as *.bak before being replaced.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cfg="${XDG_CONFIG_HOME:-$HOME/.config}"
cd "$repo"

branch="$(git rev-parse --abbrev-ref HEAD)"
echo ":: pulling $branch"
git pull --ff-only origin "$branch"
git --no-pager log --oneline -1

backup_cp() {   # backup_cp SRC DEST — copy, keeping the old DEST as DEST.bak
  mkdir -p "$(dirname "$2")"
  [ -f "$2" ] && cp "$2" "$2.bak"
  cp "$1" "$2"
}

echo ":: applying Hyprland config"
backup_cp profiles/hyprland/hyprland.conf "$cfg/hypr/hyprland.conf"
if [ -d profiles/hyprland/scripts ]; then
  mkdir -p "$cfg/hypr/scripts"
  cp profiles/hyprland/scripts/* "$cfg/hypr/scripts/"
  chmod +x "$cfg/hypr/scripts/"*
fi

if [ -f profiles/kitty/kitty.conf ]; then
  echo ":: applying kitty config"
  backup_cp profiles/kitty/kitty.conf "$cfg/kitty/kitty.conf"
fi

echo ":: applying yorha-bar"
# Replace the folder outright so files deleted/renamed in the repo don't linger.
rm -rf "$cfg/quickshell/yorha-bar"
mkdir -p "$cfg/quickshell/yorha-bar"
cp -r profiles/quickshell/yorha-bar/. "$cfg/quickshell/yorha-bar/"

if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
  echo ":: not inside Hyprland — files copied, reload skipped"
  exit 0
fi

hyprctl reload >/dev/null
errs="$(hyprctl configerrors 2>/dev/null || true)"
if [ -n "$errs" ] && [ "$errs" != "no errors" ]; then
  echo ":: Hyprland config errors:"; echo "$errs"
else
  echo ":: Hyprland reloaded, no config errors"
fi

if grep -q "^exec-once = dms run" profiles/hyprland/hyprland.conf; then
  # Daily setup: DMS owns bar/notifications/idle/wallpaper — stop the YoRHa
  # pieces that would fight it, then (re)start DMS and the power switcher.
  pkill -f "qs -c yorha-bar" 2>/dev/null || true
  pkill -x dunst 2>/dev/null || true
  pkill -x hypridle 2>/dev/null || true
  pkill -x hyprpaper 2>/dev/null || true
  pkill -x dms 2>/dev/null || true
  sleep 0.5
  (dms run >/dev/null 2>&1 &)
  pgrep -f "hypr/scripts/power-mode.sh" >/dev/null || ("$cfg/hypr/scripts/power-mode.sh" >/dev/null 2>&1 &)
  echo ":: DMS restarted"
else
  pkill -x dms 2>/dev/null || true
  pkill -f "qs -c yorha-bar" 2>/dev/null || true
  sleep 0.3
  (qs -c yorha-bar >/dev/null 2>&1 &)
  echo ":: yorha-bar restarted (log out and back in for a fully clean switch)"
fi
