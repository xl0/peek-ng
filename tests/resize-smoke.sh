#!/bin/bash
# Regression: GTK's XI2 corner-resize fallback can stall on a hollow window
# under awesome. Always creates a private display; never drives the desktop.
# Usage: tests/resize-smoke.sh [peek binary]
#        COMPOSITOR=yes tests/resize-smoke.sh   # also run picom (XRender)
set -euo pipefail
export PEEK=$(realpath "${1:-builddir/src/peek}")
export WORK=$(mktemp -d /tmp/peek-resize.XXXXXX)
echo "Resize test logs: $WORK"
export XDG_CONFIG_HOME=$WORK/config XDG_CACHE_HOME=$WORK/cache
export GSETTINGS_BACKEND=keyfile GSETTINGS_SCHEMA_DIR=$WORK/schemas
export GDK_BACKEND=x11
# The regression requires XI2, not GTK's core-input workaround.
unset GDK_CORE_DEVICE_EVENTS
mkdir -p "$WORK/schemas"
glib-compile-schemas "$(dirname "$0")/../data" --targetdir="$WORK/schemas"
gsettings set com.uploadedlobster.peek persist-window-geometry '(300, 100, 1885, 1262)'
gsettings set com.uploadedlobster.peek interface-size-indicator-delay "${INDICATOR_DELAY:-1600}"

cat > "$WORK/rc.lua" <<'LUA'
local awful = require('awful')
awful.screen.connect_for_each_screen(function(s)
    awful.tag({'test'}, s, awful.layout.suit.floating)
end)
awful.rules.rules = {{rule = {}, properties = {
    floating = true, border_width = 1, titlebars_enabled = false,
    placement = awful.placement.centered
}}}
LUA

cat > "$WORK/probe.py" <<'PY'
import ctypes as C
import os
import re
import subprocess
import threading
import time

x = C.CDLL('libX11.so.6')
assert x.XInitThreads(), 'Xlib threading initialization failed'
xt = C.CDLL('libXtst.so.6')
shape = C.CDLL('libXext.so.6')
p, ul, i, ui = C.c_void_p, C.c_ulong, C.c_int, C.c_uint
x.XOpenDisplay.argtypes = [C.c_char_p]
x.XOpenDisplay.restype = p
x.XDefaultRootWindow.argtypes = [p]
x.XDefaultRootWindow.restype = ul
x.XFlush.argtypes = [p]
x.XCloseDisplay.argtypes = [p]
x.XFree.argtypes = [p]
x.XGetGeometry.argtypes = [p, ul, p, p, p, p, p, p, p]
x.XTranslateCoordinates.argtypes = [p, ul, ul, i, i, p, p, p]
xt.XTestFakeMotionEvent.argtypes = [p, i, i, i, ul]
xt.XTestFakeButtonEvent.argtypes = [p, ui, i, ul]

class Rectangle(C.Structure):
    _fields_ = [('x', C.c_short), ('y', C.c_short),
                ('width', C.c_ushort), ('height', C.c_ushort)]

shape.XShapeGetRectangles.argtypes = [p, ul, i, p, p]
shape.XShapeGetRectangles.restype = C.POINTER(Rectangle)
d = x.XOpenDisplay(None)
assert d, 'Cannot open private display'
root = x.XDefaultRootWindow(d)
for _ in range(100):
    tree = subprocess.check_output(['xwininfo', '-root', '-tree'], text=True)
    # Skip GTK's unmapped 10x10 application leader window.
    match = re.search(r'(0x[0-9a-f]+) "Peek"[^\n]*\s[1-9][0-9]{2,}x[1-9][0-9]{2,}', tree)
    if match:
        break
    time.sleep(.1)
else:
    raise AssertionError('Peek window did not appear: ' + tree)
window = int(match[1], 16)

def geometry():
    rr, child = ul(), ul()
    xx, yy, width, height, border, depth = i(), i(), ui(), ui(), ui(), ui()
    x.XGetGeometry(d, window, C.byref(rr), C.byref(xx), C.byref(yy),
                   C.byref(width), C.byref(height), C.byref(border), C.byref(depth))
    x.XTranslateCoordinates(d, window, root, 0, 0,
                            C.byref(xx), C.byref(yy), C.byref(child))
    return xx.value, yy.value, width.value, height.value

def center_in_shape(kind):
    _, _, width, height = geometry()
    count, order = i(), i()
    rects = shape.XShapeGetRectangles(d, window, kind, C.byref(count), C.byref(order))
    inside = any(r.x <= width // 2 < r.x + r.width and
                 r.y <= height // 2 < r.y + r.height for r in rects[:count.value])
    x.XFree(rects)
    return inside

for corner in ('bottom-right', 'top-left'):
    time.sleep(3)  # Wait for the size overlay to disappear and the hole to return.
    assert not center_in_shape(0), 'Bounding hole not restored'
    assert not center_in_shape(2), 'Input hole not restored'
    gx, gy, width, height = geometry()
    if corner == 'bottom-right':
        px, py, sign = gx + width - 2, gy + height - 2, -1
    else:
        px, py, sign = gx + 2, gy + 2, 1
    xt.XTestFakeMotionEvent(d, 0, px, py, 0)
    xt.XTestFakeButtonEvent(d, 1, True, 0)
    x.XFlush(d)
    # Exercise waiting before motion as well as pausing halfway through a drag.
    time.sleep(3 if corner == 'bottom-right' else .1)
    start = time.monotonic()
    duration = 2 if corner == 'bottom-right' else 4

    def feed():
        # Independent connection: geometry round trips must not throttle input.
        display = x.XOpenDisplay(None)
        assert display
        for step in range(1, 2001):
            pause = 2 if corner == 'top-left' and step > 1000 else 0
            time.sleep(max(0, start + step * .001 + pause - time.monotonic()))
            xt.XTestFakeMotionEvent(display, 0, px + sign * (step // 5),
                                   py + sign * (step // 10), 0)
            x.XFlush(display)
        x.XCloseDisplay(display)

    feeder = threading.Thread(target=feed)
    feeder.start()
    sizes, resumed_sizes = set(), set()
    while time.monotonic() - start < duration - .2:
        size = geometry()[2:]
        sizes.add(size)
        if time.monotonic() - start > duration - .8:
            resumed_sizes.add(size)
        time.sleep(.01)
    feeder.join()
    overlay_visible = center_in_shape(0)
    xt.XTestFakeButtonEvent(d, 1, False, 0)
    x.XFlush(d)
    print(f'{corner}: {len(sizes)} distinct sizes during drag', flush=True)
    assert len(sizes) >= 10, 'Corner resize stalled during continuous XI2 motion'
    assert len(resumed_sizes) >= 10, 'Corner resize stalled after a pause'
    assert overlay_visible, 'Bounding hole was not cleared while resizing'

time.sleep(3)
assert not center_in_shape(0), 'Bounding hole not restored after resize'
assert not center_in_shape(2), 'Input hole not restored after resize'
x.XCloseDisplay(d)
print('PASS: continuous resize and click-through shapes restored')
PY

# Disabling GLX avoids NVIDIA EGL initialization in this software-only server.
xvfb-run -a -s '-screen 0 2560x1600x24 -extension GLX' dbus-run-session -- \
    bash -eu -c '
        awesome -c "$WORK/rc.lua" >"$WORK/awesome.log" 2>&1 & wm=$!
        compositor= peek=
        trap '\''kill $wm ${compositor:-} ${peek:-} 2>/dev/null || true'\'' EXIT
        sleep 1
        kill -0 "$wm"
        if [ "${COMPOSITOR:-no}" = yes ]; then
            picom --config /dev/null --backend xrender >"$WORK/picom.log" 2>&1 & compositor=$!
            sleep 1
            kill -0 "$compositor"
        fi
        "$PEEK" >"$WORK/peek.log" 2>&1 & peek=$!
        /usr/bin/python3 "$WORK/probe.py"
    '
