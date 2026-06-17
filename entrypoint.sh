#!/bin/bash
set -e

# ── Fix home directory ownership on first volume mount ─────────────────────────
if [ ! -w "$HOME" ]; then
    sudo chown -R "$USER:$USER" "$HOME"
fi

# ── Extra packages (~/packages.txt) ────────────────────────────────────────────
# Add one package name per line. Lines starting with # are ignored.
# Packages are installed on startup only when the file changes.
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
# dbus-launch provides a session bus for Electron/GTK apps.
# tint2 starts first so the taskbar appears before any windows.
# exec xfwm4 keeps the VNC session alive; session ends when xfwm4 exits.
cat > ~/.vnc/xstartup << 'EOF'
#!/bin/bash
export GTK_THEME=Arc-Dark
export GTK2_RC_FILES="$HOME/.gtkrc-2.0"
xrdb -merge ~/.Xresources
xsetroot -solid "#2b303b"
tint2 &
exec dbus-launch --exit-with-session xfwm4
EOF
chmod +x ~/.vnc/xstartup

# ── xfwm4 configuration: Arc-Dark theme ───────────────────────────────────────
# arc-theme (installed in image) ships xfwm4 themes at
# /usr/share/themes/Arc-Dark/xfwm4/ — we just point xfwm4 at it.
mkdir -p ~/.config/xfce4/xfconf/xfce-perchannel-xml
cat > ~/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="theme"            type="string" value="Arc-Dark"/>
    <property name="title_font"       type="string" value="Sans Bold 10"/>
    <property name="button_layout"    type="string" value="O|HMC"/>
    <property name="show_app_icon"    type="bool"   value="true"/>
    <property name="use_compositing"  type="bool"   value="false"/>
    <property name="frame_opacity"    type="int"    value="100"/>
    <property name="inactive_opacity" type="int"    value="100"/>
    <property name="snap_to_border"   type="bool"   value="true"/>
    <property name="snap_width"       type="int"    value="10"/>
  </property>
</channel>
EOF

# ── tint2 taskbar: launchers + tasks + tray + clock ───────────────────────────
mkdir -p ~/.config/tint2
cat > ~/.config/tint2/tint2rc << 'EOF'
# --- tint2: Arc-Dark, with app launchers on the left ---

panel_items = LTSC
panel_size = 100% 40
panel_margin = 0 0
panel_padding = 4 0 4
panel_background_id = 1
panel_position = bottom center horizontal
panel_layer = top
panel_monitor = all
panel_shrink = 0
wm_menu = 0
panel_dock = 0
panel_pivot_struts = 0
mouse_effects = 1
font_shadow = 0
panel_window_name = tint2

# Backgrounds
rounded = 0
border_width = 0
background_color = #2f343f 100
border_color = #2f343f 0

rounded = 0
border_width = 1
background_color = #3d4251 100
border_color = #5294e2 40

rounded = 0
border_width = 0
background_color = #5294e2 90
border_color = #5294e2 0

# Launcher
launcher_padding = 4 4 4
launcher_background_id = 0
launcher_icon_theme = Papirus-Dark
launcher_icon_as_tray = 0
launcher_icon_size = 24
launcher_item_app = /usr/share/applications/xfce4-terminal.desktop
launcher_item_app = /usr/share/applications/firefox.desktop
launcher_item_app = /usr/share/applications/code.desktop
launcher_item_app = /usr/share/applications/claude-desktop.desktop

# Taskbar
taskbar_mode = single_desktop
taskbar_hide_if_empty = 0
taskbar_padding = 0 0 4
taskbar_background_id = 0
taskbar_active_background_id = 0
taskbar_name = 0
taskbar_hide_inactive_tasks = 0
taskbar_always_show_all_desktop_tasks = 0
taskbar_name_padding = 0 0
taskbar_name_background_id = 0
taskbar_name_active_background_id = 0
taskbar_name_font_color = #d3dae3 100
taskbar_name_active_font_color = #ffffff 100
taskbar_distribute_size = 0
taskbar_sort_order = none
task_align = left

# Tasks
task_text = 1
task_icon = 1
task_centered = 1
task_tooltip = 1
urgent_nb_of_blink = 8
task_width = 180
task_height = 36
task_padding = 6 3 6
task_font = Sans 10
task_font_color = #d3dae3 85
task_icon_asb = 100 0 0
task_background_id = 2
task_active_background_id = 3
task_urgent_background_id = 3
task_iconified_background_id = 2
task_active_font_color = #ffffff 100
task_urgent_font_color = #f9a825 100
mouse_left = toggle_iconify
mouse_middle = close
mouse_right = none
mouse_scroll_up = prev_task
mouse_scroll_down = next_task

# Clock
time1_format = %H:%M
time1_font = Sans Bold 11
time2_format = %Y-%m-%d
time2_font = Sans 9
clock_font_color = #d3dae3 100
clock_padding = 8 0
clock_background_id = 0
clock_tooltip = %A %d %B %Y

# System tray
systray_padding = 4 4 4
systray_background_id = 0
systray_sort = ascending
systray_icon_size = 22
systray_icon_asb = 100 0 0
systray_monitor = 1
systray_name_filter =
EOF

# ── xfce4-terminal: Arc-Dark colour scheme ────────────────────────────────────
mkdir -p ~/.config/xfce4/terminal
cat > ~/.config/xfce4/terminal/terminalrc << 'EOF'
[Configuration]
FontName=Monospace 11
ColorBackground=#2f343f
ColorForeground=#d3dae3
ColorCursor=#5294e2
ColorPalette=#3b4048;#cc575d;#8bc34a;#f9a825;#5294e2;#9c71c7;#26a69a;#d3dae3;#404552;#f05b5b;#9ccc65;#fbc02d;#72a4f7;#b39ddb;#4db6ac;#ffffff
MiscShowUnsafePasteDialog=FALSE
ScrollingUnlimited=TRUE
TabActivityColor=#f9a825
EOF

# ── GTK3 settings ──────────────────────────────────────────────────────────────
mkdir -p ~/.config/gtk-3.0
cat > ~/.config/gtk-3.0/settings.ini << 'EOF'
[Settings]
gtk-theme-name=Arc-Dark
gtk-application-prefer-dark-theme=1
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=Sans 10
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle=hintfull
EOF

# ── GTK2 settings ──────────────────────────────────────────────────────────────
cat > ~/.gtkrc-2.0 << 'EOF'
gtk-theme-name="Arc-Dark"
gtk-icon-theme-name="Papirus-Dark"
gtk-font-name="Sans 10"
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle="hintfull"
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
