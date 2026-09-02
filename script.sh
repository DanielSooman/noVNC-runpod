#!/bin/bash
# setup_novnc.sh
# Installs XFCE + VNC + noVNC on a RunPod instance (Ubuntu/Debian based)
# Usage: bash setup_novnc.sh [VNC_PASSWORD] [NOVNC_PORT]
#
# Note: this reinstalls everything from scratch, since RunPod containers
# are not persistent across restarts unless you build a custom image or
# use a volume. Re-run this script any time you get a fresh container.

set -e

VNC_PASSWORD="${1:-changeme123}"
NOVNC_PORT="${2:-8080}"
VNC_DISPLAY=":1"
VNC_PORT=5901
GEOMETRY="1280x720"
DEPTH=24

export USER=root

echo "=== [1/6] Updating packages and installing XFCE + VNC + noVNC ==="
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    xfce4 xfce4-terminal dbus-x11 x11-xserver-utils \
    tigervnc-standalone-server tigervnc-common \
    novnc python3-websockify

echo "=== [2/6] Setting VNC password ==="
mkdir -p ~/.vnc
echo "$VNC_PASSWORD" | vncpasswd -f > ~/.vnc/passwd
chmod 600 ~/.vnc/passwd

echo "=== [3/6] Writing VNC startup script ==="
# IMPORTANT: use 'exec startxfce4' with no trailing '&'. Backgrounding
# startxfce4 makes this script return immediately, which VNC treats as
# the session ending, killing the desktop seconds after it starts.
cat > ~/.vnc/xstartup <<'EOF'
#!/bin/bash
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec startxfce4
EOF
chmod +x ~/.vnc/xstartup

echo "=== [4/6] Killing any existing VNC session on display $VNC_DISPLAY ==="
vncserver -kill "$VNC_DISPLAY" >/dev/null 2>&1 || true

echo "=== [5/6] Starting VNC server on display $VNC_DISPLAY (port $VNC_PORT) ==="
vncserver "$VNC_DISPLAY" -geometry "$GEOMETRY" -depth "$DEPTH"

echo "=== [6/6] Launching noVNC/websockify on port $NOVNC_PORT ==="
# nohup + disown detach the process from this shell entirely, so it
# keeps running even if the RunPod web terminal session disconnects.
pkill -f "websockify.*$NOVNC_PORT" >/dev/null 2>&1 || true
nohup websockify --web=/usr/share/novnc/ "$NOVNC_PORT" localhost:$VNC_PORT \
    > /var/log/websockify.log 2>&1 &
disown

sleep 2

echo ""
echo "============================================================"
echo " Setup complete."
echo " VNC password : $VNC_PASSWORD"
echo " VNC running  : localhost:$VNC_PORT (display $VNC_DISPLAY)"
echo " noVNC port   : $NOVNC_PORT"
echo ""
echo " Next steps:"
echo " 1. In the RunPod dashboard, expose HTTP port $NOVNC_PORT on this pod"
echo "    (Edit Pod -> Expose HTTP Ports -> add $NOVNC_PORT)."
echo " 2. Open the generated proxy URL, e.g.:"
echo "    https://<pod-id>-$NOVNC_PORT.proxy.runpod.net/vnc.html"
echo " 3. Enter the VNC password above when prompted."
echo ""
echo " Logs: /var/log/websockify.log"
echo " VNC session log: ~/.vnc/$(hostname):1.log"
echo " To restart VNC: vncserver -kill $VNC_DISPLAY && vncserver $VNC_DISPLAY -geometry $GEOMETRY -depth $DEPTH"
echo "============================================================"
