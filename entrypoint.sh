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

# ── VNC xstartup ──────────────────────────────────────────────────────────────
cat > ~/.vnc/xstartup << 'EOF'
#!/bin/bash
exec startxfce4
EOF
chmod +x ~/.vnc/xstartup

# ── Compute screen dimensions from VNC_GEOMETRY ────────────────────────────────
VNC_GEO="${VNC_GEOMETRY:-1920x1080}"
SCREEN_W="${VNC_GEO%%x*}"
SCREEN_H="${VNC_GEO##*x}"
PANEL_H=40
# Panel position: bottom-snapped, centered horizontally
PANEL_X="$((SCREEN_W / 2))"
PANEL_Y="$((SCREEN_H - PANEL_H))"

# ── XFCE4 config ───────────────────────────────────────────────────────────────
# CONFIG_VERSION: bump this to force a re-init on all existing containers.
CONFIG_VERSION=7
XFCE4_CONF="$HOME/.config/xfce4"
XFCONF="$XFCE4_CONF/xfconf/xfce-perchannel-xml"
STORED_VER=$(cat "$XFCE4_CONF/.jumpbox-version" 2>/dev/null || echo 0)

mkdir -p "$XFCONF"

# ── Always write: core WM + theme config ───────────────────────────────────────
# xfwm4 theme detection
XFWM4_THEME="Arc-Dark"
if [ ! -d "/usr/share/themes/Arc-Dark/xfwm4" ] && \
   [ ! -d "$HOME/.themes/Arc-Dark/xfwm4" ]; then
    XFWM4_THEME="Default"
fi

cat > "$XFCONF/xfwm4.xml" << XMLEOF
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="theme"             type="string" value="${XFWM4_THEME}"/>
    <property name="title_font"        type="string" value="Sans Bold 10"/>
    <property name="button_layout"     type="string" value="O|HMC"/>
    <property name="use_compositing"   type="bool"   value="false"/>
    <property name="show_app_icon"     type="bool"   value="true"/>
    <property name="workspace_count"   type="int"    value="1"/>
  </property>
</channel>
XMLEOF

cat > "$XFCONF/xsettings.xml" << 'XMLEOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xsettings" version="1.0">
  <property name="Net" type="empty">
    <property name="ThemeName"      type="string" value="Arc-Dark"/>
    <property name="IconThemeName"  type="string" value="Papirus-Dark"/>
  </property>
  <property name="Gtk" type="empty">
    <property name="FontName"            type="string" value="Sans 10"/>
    <property name="MonospaceFontName"   type="string" value="Monospace 11"/>
    <property name="CursorThemeName"     type="string" value="default"/>
    <property name="DecorationLayout"    type="string" value="menu:minimize,maximize,close"/>
  </property>
  <property name="Xft" type="empty">
    <property name="Antialias" type="int"    value="1"/>
    <property name="Hinting"   type="int"    value="1"/>
    <property name="HintStyle" type="string" value="hintfull"/>
    <property name="RGBA"      type="string" value="rgb"/>
  </property>
</channel>
XMLEOF

cat > "$XFCONF/xfce4-desktop.xml" << 'XMLEOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-desktop" version="1.0">
  <property name="backdrop" type="empty">
    <property name="screen0" type="empty">
      <property name="monitorVNC-0" type="empty">
        <property name="workspace0" type="empty">
          <property name="color-style" type="int"   value="0"/>
          <property name="image-style" type="int"   value="0"/>
          <property name="rgba1" type="array">
            <value type="double" value="0.082353"/>
            <value type="double" value="0.082353"/>
            <value type="double" value="0.082353"/>
            <value type="double" value="1.000000"/>
          </property>
        </property>
      </property>
    </property>
  </property>
</channel>
XMLEOF

# ── Always write: xfce4-panel.xml ─────────────────────────────────────────────
# Uses ONLY built-in plugins (no launcher file dependencies that can crash panel).
# Position is computed from VNC_GEOMETRY so the panel is always at the bottom.
# Plugin layout: [Apps menu] ... [Tasklist] ... [Systray] [Clock]
cat > "$XFCONF/xfce4-panel.xml" << XMLEOF
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-panel" version="1.0">
  <property name="configver" type="int" value="2"/>
  <property name="panels" type="array">
    <value type="int" value="1"/>
  </property>
  <property name="panels/panel-1" type="empty">
    <property name="position"         type="string" value="p=8;x=${PANEL_X};y=${PANEL_Y}"/>
    <property name="length"           type="uint"   value="100"/>
    <property name="position-locked"  type="bool"   value="true"/>
    <property name="autohide-behavior" type="uint"  value="0"/>
    <property name="disable-struts"   type="bool"   value="false"/>
    <property name="size"             type="uint"   value="${PANEL_H}"/>
    <property name="nrows"            type="uint"   value="1"/>
    <property name="background-style" type="uint"   value="1"/>
    <property name="background-rgba"  type="array">
      <value type="double" value="0.118"/>
      <value type="double" value="0.118"/>
      <value type="double" value="0.118"/>
      <value type="double" value="1.0"/>
    </property>
    <property name="plugin-ids" type="array">
      <value type="int" value="1"/>
      <value type="int" value="5"/>
      <value type="int" value="6"/>
      <value type="int" value="7"/>
      <value type="int" value="8"/>
      <value type="int" value="2"/>
      <value type="int" value="3"/>
      <value type="int" value="4"/>
    </property>
  </property>
  <!-- Whisker Menu: searchable application launcher -->
  <property name="plugins/plugin-1" type="string" value="whiskermenu">
    <property name="show-button-title" type="bool"   value="true"/>
    <property name="button-title"      type="string" value="Apps"/>
    <property name="show-button-icon"  type="bool"   value="true"/>
  </property>
  <!-- Launchers: Terminal, Firefox, VS Code, Claude Desktop -->
  <property name="plugins/plugin-5" type="string" value="launcher">
    <property name="items" type="array">
      <value type="string" value="jumpbox-terminal.desktop"/>
    </property>
  </property>
  <property name="plugins/plugin-6" type="string" value="launcher">
    <property name="items" type="array">
      <value type="string" value="jumpbox-firefox.desktop"/>
    </property>
  </property>
  <property name="plugins/plugin-7" type="string" value="launcher">
    <property name="items" type="array">
      <value type="string" value="jumpbox-code.desktop"/>
    </property>
  </property>
  <property name="plugins/plugin-8" type="string" value="launcher">
    <property name="items" type="array">
      <value type="string" value="claude-desktop-safe.desktop"/>
    </property>
  </property>
  <!-- Tasklist: all open/minimized windows, expands to fill available space -->
  <property name="plugins/plugin-2" type="string" value="tasklist">
    <property name="show-labels"            type="bool"   value="true"/>
    <property name="grouping"               type="bool"   value="false"/>
    <property name="expand"                 type="bool"   value="true"/>
    <property name="include-all-workspaces" type="bool"   value="true"/>
    <property name="flat-buttons"           type="bool"   value="true"/>
    <property name="show-handle"            type="bool"   value="false"/>
    <property name="show-tooltips"          type="bool"   value="true"/>
    <property name="show-wireframes"        type="bool"   value="false"/>
    <property name="middle-click"           type="uint"   value="0"/>
    <property name="window-scrolling"       type="bool"   value="true"/>
  </property>
  <!-- System tray -->
  <property name="plugins/plugin-3" type="string" value="systray">
    <property name="size-max"          type="uint"   value="22"/>
    <property name="show-frame"        type="bool"   value="false"/>
  </property>
  <!-- Clock -->
  <property name="plugins/plugin-4" type="string" value="clock">
    <property name="mode"                  type="uint"   value="2"/>
    <property name="digital-time-format"   type="string" value="%H:%M"/>
    <property name="digital-date-format"   type="string" value="%a %d %b"/>
    <property name="show-seconds"          type="bool"   value="false"/>
  </property>
</channel>
XMLEOF

# ── Always write: GTK settings ────────────────────────────────────────────────
mkdir -p ~/.config/gtk-3.0
cat > ~/.config/gtk-3.0/settings.ini << 'EOF'
[Settings]
gtk-theme-name=Arc-Dark
gtk-application-prefer-dark-theme=1
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=Sans 10
EOF

cat > ~/.gtkrc-2.0 << 'EOF'
gtk-theme-name="Arc-Dark"
gtk-icon-theme-name="Papirus-Dark"
gtk-font-name="Sans 10"
EOF

# ── Always write: autostart entries ───────────────────────────────────────────
# Written every start so config changes take effect on existing containers.
mkdir -p "$HOME/.config/autostart"

# Claude Desktop wrapper: safer Electron flags for containerized X11/VNC sessions.
mkdir -p "$HOME/.local/bin" "$HOME/.local/share/applications"
cat > "$HOME/.local/bin/claude-desktop" << 'EOF'
#!/bin/bash
set -e

if [ -x /usr/bin/claude-desktop ]; then
  BIN=/usr/bin/claude-desktop
elif [ -x /usr/local/bin/claude-desktop ]; then
  BIN=/usr/local/bin/claude-desktop
else
  echo "claude-desktop binary not found" >&2
  exit 127
fi

exec "$BIN" \
  --no-sandbox \
  --disable-gpu \
  --disable-dev-shm-usage \
  --password-store=basic \
  "$@"
EOF
chmod +x "$HOME/.local/bin/claude-desktop"
ln -sf "$HOME/.local/bin/claude-desktop" "$HOME/.local/bin/clause-desktop"

CLAUDE_ICON="claude-desktop"
for CFILE in "$HOME/.local/share/applications"/*.desktop /usr/share/applications/*.desktop /usr/local/share/applications/*.desktop; do
  [ -f "$CFILE" ] || continue
  case "$(basename "$CFILE" | tr '[:upper:]' '[:lower:]')" in
    *claude*.desktop)
      CANDIDATE_ICON=$(grep -m1 '^Icon=' "$CFILE" | cut -d= -f2-)
      if [ -n "$CANDIDATE_ICON" ]; then
        CLAUDE_ICON="$CANDIDATE_ICON"
        break
      fi
      ;;
  esac
done

cat > "$HOME/.local/share/applications/claude-desktop-safe.desktop" << EOF
[Desktop Entry]
Name=Claude Desktop
Comment=Claude Desktop (container-safe launcher)
Exec=$HOME/.local/bin/claude-desktop %U
Icon=$CLAUDE_ICON
Terminal=false
Type=Application
Categories=Utility;
StartupNotify=true
EOF

cat > "$HOME/.local/share/applications/jumpbox-terminal.desktop" << 'EOF'
[Desktop Entry]
Name=Terminal
Comment=XFCE Terminal
Exec=xfce4-terminal
Icon=utilities-terminal
Terminal=false
Type=Application
Categories=System;TerminalEmulator;
StartupNotify=true
EOF

cat > "$HOME/.local/share/applications/jumpbox-firefox.desktop" << 'EOF'
[Desktop Entry]
Name=Firefox
Comment=Web Browser
Exec=firefox %u
Icon=firefox
Terminal=false
Type=Application
Categories=Network;WebBrowser;
StartupNotify=true
EOF

cat > "$HOME/.local/share/applications/jumpbox-code.desktop" << 'EOF'
[Desktop Entry]
Name=VS Code
Comment=Code Editor
Exec=code --no-sandbox --unity-launch %F
Icon=code
Terminal=false
Type=Application
Categories=Development;IDE;
StartupNotify=true
EOF

# ── Dock behavior: disable Plank, use fixed XFCE panel only ──────────────────
# Plank has continued to reposition in fullscreen; disable it for deterministic
# layout. The XFCE bottom panel above remains position-locked.
mkdir -p "$HOME/.config/autostart"
rm -f "$HOME/.config/autostart/plank.desktop"
pkill -x plank 2>/dev/null || true

cat > "$HOME/.config/autostart/picom.desktop" << 'EOF'
[Desktop Entry]
Name=picom
Comment=Compositor — rounded corners, no shadows
Exec=picom --backend xrender --corner-radius 8 --no-fading-openclose --no-shadow
Type=Application
X-GNOME-Autostart-enabled=true
EOF

# ── First-run / version-upgrade: write config that persists across restarts ───
if [ "$STORED_VER" -lt "$CONFIG_VERSION" ]; then
    echo "Jumpbox: initialising config (v${CONFIG_VERSION})..."

    # xfce4-terminal dark palette
    mkdir -p "$HOME/.config/xfce4/terminal"
    cat > "$HOME/.config/xfce4/terminal/terminalrc" << 'EOF'
[Configuration]
FontName=Monospace 11
ColorBackground=#1e1e1e
ColorForeground=#d4d4d4
ColorCursor=#5294e2
ColorPalette=#1e1e1e;#f44747;#608b4e;#dcdcaa;#569cd6;#c678dd;#56b6c2;#d4d4d4;#808080;#f44747;#608b4e;#dcdcaa;#569cd6;#c678dd;#56b6c2;#ffffff
MiscShowUnsafePasteDialog=FALSE
ScrollingUnlimited=TRUE
EOF

    echo "$CONFIG_VERSION" > "$XFCE4_CONF/.jumpbox-version"
    echo "Done."
fi

# ── Kill any stale VNC lock ────────────────────────────────────────────────────
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

exec websockify --web /usr/share/novnc/ 6080 localhost:5901
