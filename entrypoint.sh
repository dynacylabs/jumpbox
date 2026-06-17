#!/bin/bash
set -e

# ── Fix home directory ownership on first volume mount ─────────────────────────
if [ ! -w "$HOME" ]; then
    sudo chown -R "$USER:$USER" "$HOME"
fi

# ── Extra packages (~/packages.txt) ────────────────────────────────────────────
PACKAGES_FILE="$HOME/packages.txt"
PACKAGES_STAMP="$HOME/.packages.stamp"
if [ -f "$PACKAGES_FILE" ] && [ -s "$PACKAGES_FILE" ]; then
    PACKAGES_HASH=$(md5sum "$PACKAGES_FILE" | cut -d' ' -f1)
    LAST_HASH=""
    [ -f "$PACKAGES_STAMP" ] && LAST_HASH=$(cat "$PACKAGES_STAMP")
    if [ "$PACKAGES_HASH" != "$LAST_HASH" ]; then
        echo "packages.txt changed — installing packages..."
        PACKAGES=$(grep -v '^\s*#' "$PACKAGES_FILE" | grep -v '^\s*$' | tr '\n' ' ')
        sudo apt-get update -qq
        # shellcheck disable=SC2086
        sudo apt-get install -y $PACKAGES
        echo "$PACKAGES_HASH" > "$PACKAGES_STAMP"
        echo "Done."
    fi
fi

# ── VNC password ───────────────────────────────────────────────────────────────
mkdir -p ~/.vnc
printf '%s' "${VNC_PASSWORD:-changeme}" | vncpasswd -f > ~/.vnc/passwd
chmod 600 ~/.vnc/passwd

# ── VNC xstartup ──────────────────────────────────────────────────────────────
# startxfce4 manages its own D-Bus session via xfce4-session.
cat > ~/.vnc/xstartup << 'EOF'
#!/bin/bash
exec startxfce4
EOF
chmod +x ~/.vnc/xstartup

# ── XFCE4 config — written on first container start, preserved across restarts ─
# Delete the marker to force a re-write: rm ~/.config/xfce4/.jumpbox-init
XFCE4_CONF="$HOME/.config/xfce4"
XFCONF="$XFCE4_CONF/xfconf/xfce-perchannel-xml"

if [ ! -f "$XFCE4_CONF/.jumpbox-init" ]; then
    echo "First-run: configuring XFCE4..."

    # ── Determine xfwm4 theme (arc-theme includes xfwm4 on Ubuntu) ────────────
    XFWM4_THEME="Arc-Dark"
    if [ ! -d "/usr/share/themes/Arc-Dark/xfwm4" ] && [ ! -d "$HOME/.themes/Arc-Dark/xfwm4" ]; then
        XFWM4_THEME="Default"
        echo "  arc-theme xfwm4 not found, using Default"
    fi

    mkdir -p "$XFCONF"

    # ── xfwm4: theme, compositing OFF (picom handles it), button layout ───────
    cat > "$XFCONF/xfwm4.xml" << XMLEOF
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="theme"             type="string"  value="${XFWM4_THEME}"/>
    <property name="title_font"        type="string"  value="Sans Bold 10"/>
    <property name="button_layout"     type="string"  value="O|HMC"/>
    <property name="use_compositing"   type="bool"    value="false"/>
    <property name="show_app_icon"     type="bool"    value="true"/>
    <property name="titleless_maximize" type="bool"   value="false"/>
    <property name="workspace_count"   type="int"     value="1"/>
  </property>
</channel>
XMLEOF

    # ── xsettings: GTK theme, icons, fonts ────────────────────────────────────
    cat > "$XFCONF/xsettings.xml" << 'XMLEOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xsettings" version="1.0">
  <property name="Net" type="empty">
    <property name="ThemeName"     type="string" value="Arc-Dark"/>
    <property name="IconThemeName" type="string" value="Papirus-Dark"/>
  </property>
  <property name="Gtk" type="empty">
    <property name="FontName"         type="string" value="Sans 10"/>
    <property name="CursorThemeName"  type="string" value="default"/>
    <property name="DecorationLayout" type="string" value="menu:minimize,maximize,close"/>
    <property name="MonospaceFontName" type="string" value="Monospace 11"/>
  </property>
  <property name="Xft" type="empty">
    <property name="Antialias" type="int"    value="1"/>
    <property name="Hinting"   type="int"    value="1"/>
    <property name="HintStyle" type="string" value="hintfull"/>
    <property name="RGBA"      type="string" value="rgb"/>
  </property>
</channel>
XMLEOF

    # ── xfce4-desktop: solid dark background ─────────────────────────────────
    cat > "$XFCONF/xfce4-desktop.xml" << 'XMLEOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-desktop" version="1.0">
  <property name="backdrop" type="empty">
    <property name="screen0" type="empty">
      <property name="monitorVNC-0" type="empty">
        <property name="workspace0" type="empty">
          <property name="color-style"  type="int"    value="0"/>
          <property name="image-style"  type="int"    value="0"/>
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

    # ── xfce4-panel: bottom bar, launchers + tasklist + systray + clock ───────
    # Launcher plugin dirs must exist with the .desktop files inside them.
    # Plugin IDs: 1=launcher(term), 2=launcher(ff), 3=launcher(code),
    #             4=launcher(claude), 5=tasklist, 6=systray, 7=clock
    for APP in "1:xfce4-terminal" "2:firefox" "3:code" "4:claude-desktop"; do
        ID="${APP%%:*}"
        DESKTOP_NAME="${APP##*:}"
        LAUNCHER_DIR="$HOME/.config/xfce4/panel/launcher-${ID}"
        mkdir -p "$LAUNCHER_DIR"
        if [ -f "/usr/share/applications/${DESKTOP_NAME}.desktop" ]; then
            cp "/usr/share/applications/${DESKTOP_NAME}.desktop" \
               "$LAUNCHER_DIR/${DESKTOP_NAME}.desktop"
        fi
    done

    cat > "$XFCONF/xfce4-panel.xml" << 'XMLEOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-panel" version="1.0">
  <property name="configver" type="int" value="2"/>
  <property name="panels" type="array">
    <value type="int" value="1"/>
  </property>
  <property name="panels/panel-1" type="empty">
    <property name="position"        type="string" value="p=8;x=0;y=0"/>
    <property name="length"          type="uint"   value="100"/>
    <property name="position-locked" type="bool"   value="true"/>
    <property name="size"            type="uint"   value="40"/>
    <property name="nrows"           type="uint"   value="1"/>
    <property name="background-style" type="uint"  value="1"/>
    <property name="background-rgba" type="array">
      <value type="double" value="0.118"/>
      <value type="double" value="0.118"/>
      <value type="double" value="0.118"/>
      <value type="double" value="1.0"/>
    </property>
    <property name="plugin-ids" type="array">
      <value type="int" value="1"/>
      <value type="int" value="2"/>
      <value type="int" value="3"/>
      <value type="int" value="4"/>
      <value type="int" value="5"/>
      <value type="int" value="6"/>
      <value type="int" value="7"/>
    </property>
  </property>
  <!-- Launchers -->
  <property name="plugins/plugin-1" type="string" value="launcher">
    <property name="items" type="array">
      <value type="string" value="xfce4-terminal.desktop"/>
    </property>
  </property>
  <property name="plugins/plugin-2" type="string" value="launcher">
    <property name="items" type="array">
      <value type="string" value="firefox.desktop"/>
    </property>
  </property>
  <property name="plugins/plugin-3" type="string" value="launcher">
    <property name="items" type="array">
      <value type="string" value="code.desktop"/>
    </property>
  </property>
  <property name="plugins/plugin-4" type="string" value="launcher">
    <property name="items" type="array">
      <value type="string" value="claude-desktop.desktop"/>
    </property>
  </property>
  <!-- Tasklist (expands to fill remaining space) -->
  <property name="plugins/plugin-5" type="string" value="tasklist">
    <property name="show-labels"  type="bool" value="true"/>
    <property name="grouping"     type="bool" value="false"/>
    <property name="expand"       type="bool" value="true"/>
    <property name="flat-buttons" type="bool" value="true"/>
  </property>
  <!-- System tray -->
  <property name="plugins/plugin-6" type="string" value="systray">
    <property name="size-max"        type="uint" value="22"/>
    <property name="show-frame"      type="bool" value="false"/>
  </property>
  <!-- Clock -->
  <property name="plugins/plugin-7" type="string" value="clock">
    <property name="mode"                type="uint"   value="2"/>
    <property name="digital-time-format" type="string" value="%H:%M"/>
    <property name="digital-date-format" type="string" value="%a %d %b"/>
    <property name="show-seconds"        type="bool"   value="false"/>
  </property>
</channel>
XMLEOF

    # ── picom autostart (rounded corners, xfwm4 compositor stays off) ─────────
    mkdir -p "$HOME/.config/autostart"
    cat > "$HOME/.config/autostart/picom.desktop" << 'DESKTOPEOF'
[Desktop Entry]
Name=picom
Comment=Compositor with rounded corners
Exec=picom --backend xrender --corner-radius 8 --shadow --shadow-radius 14 --shadow-opacity 0.45 --shadow-offset-x -10 --shadow-offset-y -10 --no-fading-openclose --shadow-exclude "window_type = 'dock'" --shadow-exclude "window_type = 'menu'" --shadow-exclude "window_type = 'tooltip'"
Type=Application
X-GNOME-Autostart-enabled=true
DESKTOPEOF

    # ── xfce4-terminal: dark VS Code-style palette ────────────────────────────
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

    touch "$XFCE4_CONF/.jumpbox-init"
    echo "XFCE4 config written."
fi

# ── GTK fallback (for apps started outside the XFCE settings daemon) ──────────
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
