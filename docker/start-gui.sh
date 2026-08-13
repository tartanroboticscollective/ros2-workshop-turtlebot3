#!/bin/bash
# Start the in-container X server, a window manager and the noVNC bridge.
# Idempotent: safe to call again if something died.

VNC_GEOMETRY="${VNC_GEOMETRY:-1920x1080}"
VNC_DISPLAY="${VNC_DISPLAY:-:1}"
NOVNC_PORT="${NOVNC_PORT:-6080}"
RFB_PORT="${RFB_PORT:-5901}"

if ! pgrep -x Xtigervnc >/dev/null; then
    rm -f /tmp/.X"${VNC_DISPLAY#:}"-lock "/tmp/.X11-unix/X${VNC_DISPLAY#:}"
    Xtigervnc "$VNC_DISPLAY" \
        -geometry "$VNC_GEOMETRY" \
        -depth 24 \
        -SecurityTypes None \
        -AlwaysShared \
        -rfbport "$RFB_PORT" \
        -desktop ros2-workshop \
        >/var/log/vnc.log 2>&1 &

    for _ in $(seq 50); do
        [ -e "/tmp/.X11-unix/X${VNC_DISPLAY#:}" ] && break
        sleep 0.2
    done
fi

if ! pgrep -x openbox >/dev/null; then
    DISPLAY="$VNC_DISPLAY" openbox >/var/log/openbox.log 2>&1 &
fi

if ! pgrep -f "websockify.*$NOVNC_PORT" >/dev/null; then
    websockify --web=/usr/share/novnc "$NOVNC_PORT" "localhost:$RFB_PORT" \
        >/var/log/novnc.log 2>&1 &
fi

echo "GUI ready -> http://localhost:${NOVNC_PORT}/vnc.html?autoconnect=1&resize=remote"
