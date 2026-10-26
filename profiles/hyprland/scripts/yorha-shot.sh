#!/usr/bin/env bash
# YoRHa screenshot tool.
#
#   yorha-shot.sh region   drag a box  -> saved + copied
#   yorha-shot.sh full     whole screen -> saved + copied
#   yorha-shot.sh window   active window -> saved + copied
#   yorha-shot.sh edit     drag a box  -> opens in swappy to annotate
#
# Saved to ~/Pictures/Screenshots/YYYY-MM-DD_HH-MM-SS.png and always copied to
# the clipboard. The notification has an "Edit" action (middle-click it in
# dunst) that opens the shot in swappy. Esc during selection cancels quietly.
set -uo pipefail

mode="${1:-region}"
dir="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")/Screenshots"
mkdir -p "$dir"
file="$dir/$(date +'%Y-%m-%d_%H-%M-%S').png"

# Selection box in the YoRHa palette: ink wash, rust border.
pick() { slurp -b '#4a473944' -c '#bb5b32ff' -s '#00000000' -w 2; }

case "$mode" in
  region)
    geo="$(pick)" || exit 0
    grim -g "$geo" "$file" ;;
  full)
    grim "$file" ;;
  window)
    geo="$(hyprctl activewindow -j | jq -r 'if .at then "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])" else empty end')"
    [ -n "$geo" ] || { notify-send -a "Screenshot" "No active window"; exit 1; }
    grim -g "$geo" "$file" ;;
  edit)
    geo="$(pick)" || exit 0
    grim -g "$geo" - | swappy -f - -o "$file"
    [ -f "$file" ] && wl-copy < "$file"
    exit 0 ;;
  *)
    echo "usage: $(basename "$0") region|full|window|edit" >&2; exit 2 ;;
esac

[ -f "$file" ] || exit 1
wl-copy < "$file"

# Notify with a thumbnail; the Edit action opens swappy. Runs in the background
# so the keybind returns immediately.
(
  act="$(notify-send -a "Screenshot" -i "$file" -A edit=Edit \
         "Screenshot saved" "Copied to clipboard · $(basename "$file")")"
  [ "$act" = "edit" ] && swappy -f "$file"
) >/dev/null 2>&1 &
