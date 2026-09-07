#!/bin/bash
# UI smoke test: drives the real peek binary on the current X display with
# xdotool and the ffmpeg backend, and checks the log, the output folder and
# the cache folder after each scenario. Settings and cache are isolated in a
# temp dir, but the global Ctrl+Alt+R hotkey is grabbed and the screen is
# really recorded, so do not run it on a display you are using.
#
#   tests/ui-smoke.sh [path/to/peek]
#
# Headless (what CI does):
#   xvfb-run -a -s "-screen 0 1280x800x24" dbus-run-session -- \
#     bash -c 'openbox & sleep 1; tests/ui-smoke.sh'
set -euo pipefail

PEEK=$(realpath "${1:-builddir/src/peek}")
SRC=$(realpath "$(dirname "$0")/..")
WORK=$(mktemp -d)
LOG=$WORK/peek.log
PEEK_PID=

cleanup() {
  [ -n "$PEEK_PID" ] && kill "$PEEK_PID" 2>/dev/null || true
  rm -rf "$WORK"
}
trap cleanup EXIT

# Isolated settings (keyfile backend, shared with the gsettings CLI) and cache.
export XDG_CONFIG_HOME=$WORK/config XDG_CACHE_HOME=$WORK/cache
export GSETTINGS_BACKEND=keyfile GSETTINGS_SCHEMA_DIR=$WORK/schemas
mkdir -p "$WORK/out" "$WORK/schemas"
glib-compile-schemas "$SRC/data" --targetdir="$WORK/schemas"
S=com.uploadedlobster.peek
gsettings set $S recording-start-delay 0
gsettings set $S persist-save-folder "$WORK/out"
gsettings set $S interface-show-notification false
# Takes follow each other within a minute; avoid the overwrite confirmation.
gsettings set $S interface-default-file-name-format "peek-%H-%M-%S"

fail() {
  echo "FAIL: $*"
  ffmpeg -loglevel error -y -f x11grab -i "$DISPLAY" -frames:v 1 "${UI_SMOKE_SHOT:-/tmp/ui-smoke-fail.png}" || true
  echo "--- windows"; xdotool search --onlyvisible --name . 2>/dev/null | while read -r w; do echo "$w $(xdotool getwindowname "$w")"; done
  echo "--- peek.log (filtered)"
  grep -v -E "dconf|Gtk-DEBUG|recording-area|GLib-GIO|Gdk-DEBUG" "$LOG" | tail -30
  exit 1
}
count() { grep -c -- "$1" "$LOG" || true; }
# wait_count PATTERN N: wait until the log contains PATTERN at least N times
wait_count() {
  for _ in $(seq 60); do
    [ "$(count "$1")" -ge "$2" ] && return 0
    sleep 0.5
  done
  fail "timed out waiting for '$1' x$2"
}
expect() { # expect DESCRIPTION ACTUAL EXPECTED
  [ "$2" = "$3" ] || fail "$1: expected $3, got $2"
}
outputs() { ls "$WORK/out" | wc -l; }
cache() { ls "$WORK/cache/peek" 2>/dev/null | wc -l; }

toggle() { xdotool key ctrl+alt+r; }
start_take() { toggle; wait_count "Recording area: " "$1"; sleep 0.5; }  # N-th take started
save_with_default_name() { # SAVES: how many "File saved" lines to expect afterwards
  wait_count "Showing file chooser" "$1"
  sleep 1
  local chooser
  chooser=$(xdotool search --onlyvisible --name "Save animation" | tail -1)
  xdotool windowactivate --sync "$chooser" 2>/dev/null || true
  xdotool key Return
  wait_count "File saved true" "$1"
  sleep 1
}

G_MESSAGES_DEBUG=all stdbuf -oL -eL "$PEEK" -b ffmpeg >"$LOG" 2>&1 &
PEEK_PID=$!
WID=$(xdotool search --sync --classname peek | tail -1)
sleep 1
xdotool windowactivate --sync "$WID" 2>/dev/null || true

echo "1. record and save"
start_take 1; sleep 1.5; toggle
save_with_default_name 1
expect "saved files" "$(outputs)" 1
expect "cache leftovers" "$(cache)" 0
frames=$(ffprobe -v error -count_frames -select_streams v -show_entries stream=nb_read_frames -of csv=p=0 "$WORK"/out/*.gif)
[ "$frames" -gt 5 ] || fail "gif has only $frames frames"

echo "2. cancel by moving the window, then record again"
start_take 2
eval "$(xdotool getwindowgeometry --shell "$WID")"   # sets X and Y
xdotool windowmove "$WID" $((X + 100)) $((Y + 80)); sleep 1.5
moved_from="$X,$Y"; eval "$(xdotool getwindowgeometry --shell "$WID")"
echo "   moved $moved_from -> $X,$Y; configure events seen: $(count 'Absolute recording area')"
expect "cancel logged" "$(count 'Recording canceled$')" 1
expect "no chooser after cancel" "$(count 'Showing file chooser')" 1
expect "cache after cancel" "$(cache)" 0
start_take 3; sleep 1.5; toggle
save_with_default_name 2
expect "saved files" "$(outputs)" 2
expect "cache leftovers" "$(cache)" 0

echo "3. recorder dies mid-recording, then record again"
start_take 4; sleep 1
pkill -9 -x -P "$PEEK_PID" ffmpeg
wait_count "Recording canceled: " 1
sleep 1
expect "cache after failure" "$(cache)" 0
dialog=$(xdotool search --onlyvisible --name 'Recording error' | tail -1)
[ -n "$dialog" ] || fail "no error dialog shown"
xdotool windowactivate --sync "$dialog" 2>/dev/null || true
xdotool key Escape; sleep 1
[ -z "$(xdotool search --onlyvisible --name 'Recording error')" ] || fail "error dialog did not close on Escape"
start_take 5; sleep 1.5; toggle
save_with_default_name 3
expect "saved files" "$(outputs)" 3
expect "cache leftovers" "$(cache)" 0

echo "PASS"
