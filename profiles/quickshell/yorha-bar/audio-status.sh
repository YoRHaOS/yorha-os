#!/usr/bin/env bash
# yorha-bar audio model. Parses `wpctl status` (WirePlumber) into clean,
# tab-separated lines the Quickshell Audio panel can read directly:
#
#     KIND \t ID \t DEFAULT(0|1) \t VOL \t NAME
#
# KIND is SINK (output device), SOURCE (input device), or APP (playback stream).
# Only the Audio section is read (Video is skipped). Sink/Source volumes are
# taken from the inline "[vol: X.XX]"; app streams have no inline volume, so each
# is enriched with `wpctl get-volume <id>`.
#
# No `set -e`: a parser should emit whatever it can rather than abort midway.

command -v wpctl >/dev/null 2>&1 || exit 0
status="$(wpctl status 2>/dev/null)" || exit 0
[ -n "$status" ] || exit 0

printf '%s\n' "$status" | awk '
  function emit(kind,   l, def, id, name, vol) {
    l = $0
    def = (l ~ /\*/) ? 1 : 0
    sub(/^[^0-9]*/, "", l)                        # strip tree prefix up to the id
    id = l; sub(/[.].*/, "", id)
    name = l; sub(/^[0-9]+[.][ \t]*/, "", name)
    vol = ""
    if (match(name, /\[vol: [0-9.]+/)) {
      vol = substr(name, RSTART + 6, RLENGTH - 6)
      sub(/[ \t]*\[vol:.*/, "", name)             # drop the "[vol: ...]" tail
    }
    sub(/[ \t]+$/, "", name)
    print kind "\t" id "\t" def "\t" vol "\t" name
  }
  BEGIN { a = 0; sec = "" }
  /^Audio$/    { a = 1; sec = ""; next }
  /^Video$/    { a = 0; next }
  /^Settings$/ { a = 0; next }
  a && /Devices:/ { sec = "";       next }
  a && /Sinks:/   { sec = "sink";   next }
  a && /Sources:/ { sec = "source"; next }
  a && /Filters:/ { sec = "";       next }
  a && /Streams:/ { sec = "stream"; next }
  a && sec == "sink"   && /[0-9]+[.]/ { emit("SINK");   next }
  a && sec == "source" && /[0-9]+[.]/ { emit("SOURCE"); next }
  a && sec == "stream" {
    if ($0 ~ />/)         next                     # skip port lines (output_FL > ...)
    if ($0 !~ /[0-9]+[.]/) next
    l = $0; sub(/^[^0-9]*/, "", l)
    id = l; sub(/[.].*/, "", id)
    name = l; sub(/^[0-9]+[.][ \t]*/, "", name); sub(/[ \t]+$/, "", name)
    print "APP\t" id "\t0\t\t" name
  }
' | while IFS="$(printf '\t')" read -r kind id def vol name; do
  if [ "$kind" = "APP" ] && [ -z "$vol" ]; then
    vol="$(wpctl get-volume "$id" 2>/dev/null | awk '{print $2}')"
  fi
  printf '%s\t%s\t%s\t%s\t%s\n' "$kind" "$id" "$def" "${vol:-1.00}" "$name"
done
