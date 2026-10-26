#!/usr/bin/env bash
# yorha-bar quick-toggle state. Emits tab-separated KEY \t VALUE lines so the
# Home tiles reflect the real system, not just the last click:
#
#     WIFI    \t 0|1         nmcli radio wifi
#     BT      \t 0|1         bluetoothctl show -> Powered
#     DND     \t 0|1         dunstctl is-paused
#     NIGHT   \t 0|1         hyprsunset running
#     PROFILE \t <name>      powerprofilesctl get (power-saver|balanced|performance)
#
# Each probe is skipped when its tool isn't installed, so a missing package
# leaves that tile's state alone instead of breaking the whole panel.

if command -v nmcli >/dev/null 2>&1; then
  [ "$(nmcli radio wifi 2>/dev/null)" = "enabled" ] && w=1 || w=0
  printf 'WIFI\t%s\n' "$w"
fi

if command -v bluetoothctl >/dev/null 2>&1; then
  bluetoothctl show 2>/dev/null | grep -q "Powered: yes" && b=1 || b=0
  printf 'BT\t%s\n' "$b"
fi

if command -v dunstctl >/dev/null 2>&1; then
  [ "$(dunstctl is-paused 2>/dev/null)" = "true" ] && d=1 || d=0
  printf 'DND\t%s\n' "$d"
fi

if command -v hyprsunset >/dev/null 2>&1; then
  pgrep -x hyprsunset >/dev/null 2>&1 && n=1 || n=0
  printf 'NIGHT\t%s\n' "$n"
fi

if command -v powerprofilesctl >/dev/null 2>&1; then
  p="$(powerprofilesctl get 2>/dev/null)"
  [ -n "$p" ] && printf 'PROFILE\t%s\n' "$p"
fi
