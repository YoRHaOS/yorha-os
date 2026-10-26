#!/usr/bin/env bash
# Battery / plugged-in switcher. Started once by Hyprland (exec-once).
#
#   On battery:  60Hz, power-saver profile, blur off
#   Plugged in:  native refresh (165Hz), balanced profile, blur on
#
# Checks every 10s. Refresh and blur are only touched when they differ from
# what they should be (no flicker; a `hyprctl reload` gets corrected on the
# next check). The power profile only changes at the moment you plug/unplug.

mains() {
  for d in /sys/class/power_supply/*; do
    [ "$(cat "$d/type" 2>/dev/null)" = "Mains" ] && { cat "$d/online" 2>/dev/null; return; }
  done
  echo 1   # no AC adapter found (desktop?) — treat as plugged in
}

panel() {   # internal screen: name, width, height, current refresh (integer)
  hyprctl monitors -j 2>/dev/null | jq -r '
    (map(select(.name | startswith("eDP"))) | first) // empty
    | "\(.name) \(.width) \(.height) \(.refreshRate | floor)"'
}

apply() {
  local ac="$1"
  read -r name w h hz < <(panel)

  if [ -n "${name:-}" ]; then
    if [ "$ac" = 1 ] && [ "$hz" -lt 100 ]; then
      hyprctl keyword monitor "$name,preferred,auto,1" >/dev/null
    elif [ "$ac" = 0 ] && [ "$hz" -gt 70 ]; then
      hyprctl keyword monitor "$name,${w}x${h}@60,auto,1" >/dev/null
    fi
  fi

  local want_blur=$([ "$ac" = 1 ] && echo 1 || echo 0)
  local blur
  blur="$(hyprctl getoption decoration:blur:enabled -j 2>/dev/null | jq -r '.int // empty')"
  [ -n "$blur" ] && [ "$blur" != "$want_blur" ] && \
    hyprctl keyword decoration:blur:enabled "$([ "$want_blur" = 1 ] && echo true || echo false)" >/dev/null

}

# Power profile: only switched when you plug/unplug, so picking a profile
# yourself (e.g. from DMS) isn't overridden 10 seconds later.
profile_for() {
  command -v powerprofilesctl >/dev/null 2>&1 || return
  powerprofilesctl set "$([ "$1" = 1 ] && echo balanced || echo power-saver)"
}

# Only one copy at a time (sync.sh / re-logins can start it again).
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/power-mode.lock"
flock -n 9 || exit 0

last=""
while true; do
  ac="$(mains)"
  [ "$ac" != "$last" ] && profile_for "$ac"
  last="$ac"
  apply "$ac"
  sleep 10
done
