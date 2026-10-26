#!/usr/bin/env bash
# YoRHa OS — pull the latest from GitHub and apply it to this machine.
#
#   ~/yorha-os/scripts/sync.sh
#
# Pulls the branch you're on, copies the Hyprland config and the yorha-bar
# shell into ~/.config, reloads Hyprland, restarts the bar, and reports any
# Hyprland config errors. Your previous hyprland.conf is kept as
# hyprland.conf.bak in case a change needs undoing.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cfg="${XDG_CONFIG_HOME:-$HOME/.config}"
cd "$repo"

branch="$(git rev-parse --abbrev-ref HEAD)"
echo ":: pulling $branch"
git pull --ff-only origin "$branch"
git --no-pager log --oneline -1

echo ":: applying Hyprland config"
mkdir -p "$cfg/hypr"
[ -f "$cfg/hypr/hyprland.conf" ] && cp "$cfg/hypr/hyprland.conf" "$cfg/hypr/hyprland.conf.bak"
cp profiles/hyprland/hyprland.conf "$cfg/hypr/hyprland.conf"

echo ":: applying yorha-bar"
# Replace the folder outright so files deleted/renamed in the repo don't linger
# (user settings live in ~/.config/yorha/, not here, so nothing personal is lost).
rm -rf "$cfg/quickshell/yorha-bar"
mkdir -p "$cfg/quickshell/yorha-bar"
cp -r profiles/quickshell/yorha-bar/. "$cfg/quickshell/yorha-bar/"

if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
  hyprctl reload >/dev/null
  errs="$(hyprctl configerrors 2>/dev/null)"
  if [ -n "$errs" ] && [ "$errs" != "no errors" ]; then
    echo ":: Hyprland config errors:"; echo "$errs"
  else
    echo ":: Hyprland reloaded, no config errors"
  fi
  pkill -f "qs -c yorha-bar" 2>/dev/null || true
  sleep 0.3
  (qs -c yorha-bar >/dev/null 2>&1 &)
  echo ":: bar restarted"
else
  echo ":: not inside Hyprland — files copied, reload skipped"
fi
