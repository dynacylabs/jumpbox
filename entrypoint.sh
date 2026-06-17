#!/bin/bash
set -e

# ── Fix home directory ownership on first volume mount ─────────────────────────
if [ ! -w "$HOME" ]; then
    sudo chown -R "$USER:$USER" "$HOME"
fi

# ── VNC password ───────────────────────────────────────────────────────────────
mkdir -p ~/.vnc
printf '%s' "${VNC_PASSWORD:-changeme}" | vncpasswd -f > ~/.vnc/passwd
chmod 600 ~/.vnc/passwd

# ── VNC xstartup: launch Openbox ──────────────────────────────────────────────
cat > ~/.vnc/xstartup << 'EOF'
#!/bin/bash
exec openbox-session
EOF
chmod +x ~/.vnc/xstartup

# ── Openbox autostart: the three apps ─────────────────────────────────────────
mkdir -p ~/.config/openbox
cat > ~/.config/openbox/autostart << 'EOF'
xterm &
firefox &
code --no-sandbox --disable-gpu &
EOF

# ── Kill any stale VNC lock from a previous run ────────────────────────────────
tigervncserver -kill :1 2>/dev/null || true
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1

# ── Start TigerVNC ────────────────────────────────────────────────────────────
tigervncserver :1 \
    -geometry "${VNC_GEOMETRY:-1920x1080}" \
    -depth 24 \
    -localhost no

echo ""
echo "┌────────────────────────────────────────────────────────────┐"
echo "│  Jumpbox is running!                                       │"
echo "│  Open in your browser:                                     │"
echo "│  http://localhost:6080/vnc.html                            │"
echo "└────────────────────────────────────────────────────────────┘"
echo ""

# ── Start noVNC websocket proxy (keeps container alive) ────────────────────────
exec websockify --web /usr/share/novnc/ 6080 localhost:5901
