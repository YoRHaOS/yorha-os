#!/usr/bin/env bash
# yorha-bar Bluetooth model. Emits tab-separated lines for the Quickshell view:
#
#     POWER \t 0|1
#     DEV \t MAC \t PAIRED(0|1) \t CONNECTED(0|1) \t NAME
#
# Uses the documented bluetoothctl command surface (stable across bluez):
#   bluetoothctl show                 -> controller state (Powered: yes/no)
#   bluetoothctl devices [Paired|Connected]
# Paired/Connected sets are fetched once each (bluez >= 5.65 filter args) rather
# than an `info` call per device. If the filter args are unsupported the sets come
# back empty and devices still list (just without state), which degrades cleanly.

command -v bluetoothctl >/dev/null 2>&1 || exit 0

powered=0
bluetoothctl show 2>/dev/null | grep -q "Powered: yes" && powered=1
printf 'POWER\t%s\n' "$powered"
[ "$powered" = "1" ] || exit 0

paired="$(bluetoothctl devices Paired 2>/dev/null | awk '{print $2}')"
connected="$(bluetoothctl devices Connected 2>/dev/null | awk '{print $2}')"

bluetoothctl devices 2>/dev/null | while read -r _ mac name; do
  [ -n "$mac" ] || continue
  p=0; c=0
  printf '%s\n' "$paired"    | grep -qxF "$mac" && p=1
  printf '%s\n' "$connected" | grep -qxF "$mac" && c=1
  printf 'DEV\t%s\t%s\t%s\t%s\n' "$mac" "$p" "$c" "$name"
done
