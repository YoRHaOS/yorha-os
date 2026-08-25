#!/usr/bin/env bash
# yorha-bar autostart runner. Launches the session helpers the Settings view
# manages, honoring the per-item toggles in panel.conf (AUTOSTART_<name>=0 to
# disable; absent/anything-else = enabled). Items default to ON so a fresh
# install still gets its bar/notifier.
#
# Wire it once in Hyprland instead of the individual exec-once lines:
#   exec-once = ~/.config/quickshell/yorha-bar/yorha-autostart.sh

conf="${XDG_CONFIG_HOME:-$HOME/.config}/yorha/panel.conf"

start() {
  name="$1"; shift
  grep -qE "^AUTOSTART_$name=0$" "$conf" 2>/dev/null && return   # explicitly disabled
  command -v "$1" >/dev/null 2>&1 || return                      # not installed
  pgrep -x "$name" >/dev/null 2>&1 && return                     # already running
  "$@" &
}

start waybar   waybar
start dunst    dunst
start hypridle hypridle
start hyprpaper hyprpaper
