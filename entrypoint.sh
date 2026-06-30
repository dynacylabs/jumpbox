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
    # Strip comments, blank lines, and Windows carriage returns
    PACKAGES=$(grep -v '^\s*#' "$PACKAGES_FILE" | grep -v '^\s*$' | tr -d '\r' | tr '\n' ' ')
    if [ -n "$(printf '%s' "$PACKAGES" | tr -d ' ')" ]; then
        PACKAGES_HASH=$(md5sum "$PACKAGES_FILE" | cut -d' ' -f1)
        LAST_HASH=""
        [ -f "$PACKAGES_STAMP" ] && LAST_HASH=$(cat "$PACKAGES_STAMP")

        # Reinstall if the file changed OR any package is missing from this container
        # (missing happens when the container is recreated from a fresh image layer)
        NEEDS_INSTALL=false
        if [ "$PACKAGES_HASH" != "$LAST_HASH" ]; then
            NEEDS_INSTALL=true
        else
            for PKG in $PACKAGES; do
                if ! dpkg -s "$PKG" >/dev/null 2>&1; then
                    NEEDS_INSTALL=true
                    break
                fi
            done
        fi

        if [ "$NEEDS_INSTALL" = true ]; then
            echo "Installing packages: $PACKAGES"
            sudo apt-get update -qq
            # shellcheck disable=SC2086
            sudo apt-get install -y $PACKAGES
            echo "$PACKAGES_HASH" > "$PACKAGES_STAMP"
            echo "Done."
        fi
    fi
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
CONFIG_VERSION=6
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

    # Plank: left-side icon dock ─────────────────────────────────────────────
    mkdir -p "$HOME/.config/plank/dock1/launchers"

    # Helper: find first existing desktop launcher from known names and paths.
    make_dockitem() {
      local ITEM_NAME="$1"; shift
      local LAUNCHER_FILE="$HOME/.config/plank/dock1/launchers/${ITEM_NAME}.dockitem"
      local APP_DIR
      local DNAME

      for DNAME in "$@"; do
        for APP_DIR in /usr/share/applications /usr/local/share/applications; do
          if [ -f "${APP_DIR}/${DNAME}.desktop" ]; then
            printf '[PlankDockItemPreferences]\nLauncher=file://%s/%s.desktop\n' \
              "$APP_DIR" "$DNAME" > "$LAUNCHER_FILE"
            echo "$ITEM_NAME"
            return 0
          fi
        done
      done
    }

    # Helper: find first desktop launcher matching a glob pattern.
    make_dockitem_glob() {
      local ITEM_NAME="$1"
      local PATTERN="$2"
      local LAUNCHER_FILE="$HOME/.config/plank/dock1/launchers/${ITEM_NAME}.dockitem"
      local MATCH

      MATCH=$(find /usr/share/applications /usr/local/share/applications \
        -maxdepth 1 -type f -iname "$PATTERN" 2>/dev/null | sort | head -n1)
      if [ -n "$MATCH" ]; then
        printf '[PlankDockItemPreferences]\nLauncher=file://%s\n' "$MATCH" > "$LAUNCHER_FILE"
        echo "$ITEM_NAME"
        return 0
      fi
    }

    DOCK_ITEMS=""
    append_item() { [ -n "$1" ] && DOCK_ITEMS="${DOCK_ITEMS:+${DOCK_ITEMS};;}${1}.dockitem"; }

    append_item "$(make_dockitem xfce4-terminal xfce4-terminal)"
    append_item "$(make_dockitem firefox firefox firefox-esr)"
    append_item "$(make_dockitem code code visual-studio-code)"
    append_item "$(make_dockitem claude-desktop claude-desktop claude Claude)"
    if [ ! -f "$HOME/.config/plank/dock1/launchers/claude-desktop.dockitem" ]; then
      append_item "$(make_dockitem_glob claude-desktop '*claude*.desktop')"
    fi

    cat > "$HOME/.config/plank/dock1/settings" << EOF
[PlankDockPreferences]
Monitor=
HideMode=0
HideDelay=0
UnhideDelay=0
PanelMode=true
IconZoom=130
ZoomEnabled=true
Position=0
IconSize=48
Theme=Matte
DockItems=${DOCK_ITEMS}
EOF

    # Autostart: plank (dock)
    # Note: picom.desktop is written in the always-write section above.
    mkdir -p "$HOME/.config/autostart"

    cat > "$HOME/.config/autostart/plank.desktop" << 'EOF'
[Desktop Entry]
Name=Plank
Comment=App launcher dock
Exec=plank
Type=Application
X-GNOME-Autostart-enabled=true
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
