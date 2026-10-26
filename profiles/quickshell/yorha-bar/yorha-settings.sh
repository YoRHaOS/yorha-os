#!/usr/bin/env bash
# yorha-bar settings store. A tiny KEY=VALUE file the panel reads/writes.
#
#   yorha-settings.sh dump            # print all KEY=VALUE lines
#   yorha-settings.sh get KEY         # print one value
#   yorha-settings.sh set KEY VALUE   # upsert one key
#
# Stored at $XDG_CONFIG_HOME/yorha/panel.conf (default ~/.config/yorha/panel.conf).

conf="${XDG_CONFIG_HOME:-$HOME/.config}/yorha/panel.conf"
mkdir -p "$(dirname "$conf")"
[ -f "$conf" ] || : > "$conf"

case "${1:-dump}" in
  dump) cat "$conf" ;;
  get)  grep -E "^$2=" "$conf" | tail -n1 | cut -d= -f2- ;;
  set)
    rest="$(grep -vE "^$2=" "$conf" 2>/dev/null)"
    { [ -n "$rest" ] && printf '%s\n' "$rest"; printf '%s=%s\n' "$2" "$3"; } > "$conf"
    ;;
esac
