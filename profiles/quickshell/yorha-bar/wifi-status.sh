#!/usr/bin/env bash
# yorha-bar WiFi model. Emits tab-separated lines for the Quickshell Network view:
#
#     NET \t INUSE(0|1) \t SIGNAL(0-100) \t SECURITY \t SSID
#     SAVED \t SSID
#
# Uses nmcli terse mode (-t) rather than the human column layout, so parsing is
# stable. nmcli escapes ':' and '\' in values with a backslash; we un-escape them
# before splitting. SAVED lines list known connection profiles so the UI can
# connect without a password prompt. Duplicate SSIDs are de-duplicated (strongest
# signal first, which is nmcli's default order).

command -v nmcli >/dev/null 2>&1 || exit 0

nmcli -t -f IN-USE,SIGNAL,SECURITY,SSID device wifi list 2>/dev/null | awk '
{
  line = $0
  gsub(/\\\\/, "\001", line)          # protect escaped backslash
  gsub(/\\:/,  "\002", line)          # protect escaped colon
  n = split(line, f, ":")
  for (i = 1; i <= n; i++) { gsub(/\001/, "\\", f[i]); gsub(/\002/, ":", f[i]) }
  inuse = (f[1] ~ /\*/) ? 1 : 0
  signal = f[2]
  security = f[3]
  ssid = f[4]
  for (i = 5; i <= n; i++) ssid = ssid ":" f[i]   # (colons already protected; defensive)
  if (ssid == "") next
  if (seen[ssid]++) next
  print "NET\t" inuse "\t" signal "\t" security "\t" ssid
}'

# Known/saved WiFi profiles (so the UI can connect without asking for a password).
nmcli -t -f NAME connection show 2>/dev/null | while IFS= read -r name; do
  [ -n "$name" ] && printf 'SAVED\t%s\n' "$name"
done
