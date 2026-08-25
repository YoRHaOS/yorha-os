#!/usr/bin/env bash
# yorha-bar audio model. Parses `wpctl status` (WirePlumber) into clean,
# tab-separated lines the Quickshell Audio panel can read directly:
#
#     KIND \t ID \t DEFAULT(0|1) \t VOL \t NAME
#
# KIND is SINK (output device), SOURCE (input device), or APP (playback stream).
# Only the Audio section is read (Video is skipped). Sink/Source volumes come from
# the inline "[vol: X.XX]"; app streams have no inline volume, so each is enriched
# with `wpctl get-volume <id>` fetched from inside awk (via `cmd | getline`) so
# every emitted line is complete — no empty fields (an empty field would collapse
# in a later `read` because tab is IFS-whitespace, which previously blanked names).

command -v wpctl >/dev/null 2>&1 || exit 0

wpctl status 2>/dev/null | awk '
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
    if (vol == "") vol = "1.00"
    print kind "\t" id "\t" def "\t" vol "\t" name
  }
  function appvol(id,   c, line, arr, v) {         # per-app volume via get-volume
    c = "wpctl get-volume " id " 2>/dev/null"
    v = "1.00"
    if ((c | getline line) > 0) { split(line, arr, " "); if (arr[2] != "") v = arr[2] }
    close(c)
    return v
  }
  BEGIN { inaud = 0; sec = "" }
  /^Audio$/    { inaud = 1; sec = ""; next }
  /^Video$/    { inaud = 0; next }
  /^Settings$/ { inaud = 0; next }
  inaud && /Devices:/ { sec = "";       next }
  inaud && /Sinks:/   { sec = "sink";   next }
  inaud && /Sources:/ { sec = "source"; next }
  inaud && /Filters:/ { sec = "";       next }
  inaud && /Streams:/ { sec = "stream"; next }
  inaud && sec == "sink"   && /[0-9]+[.]/ { emit("SINK");   next }
  inaud && sec == "source" && /[0-9]+[.]/ { emit("SOURCE"); next }
  inaud && sec == "stream" {
    if ($0 ~ />/)          next                    # skip port lines (output_FL > ...)
    if ($0 !~ /[0-9]+[.]/) next
    l = $0; sub(/^[^0-9]*/, "", l)
    id = l; sub(/[.].*/, "", id)
    name = l; sub(/^[0-9]+[.][ \t]*/, "", name); sub(/[ \t]+$/, "", name)
    print "APP\t" id "\t0\t" appvol(id) "\t" name
  }
'
