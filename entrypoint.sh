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
# Export GTK theme vars here so every child process (apps, tint2) inherits them.
cat > ~/.vnc/xstartup << 'EOF'
#!/bin/bash
export GTK_THEME=Arc-Dark
export GTK2_RC_FILES="$HOME/.gtkrc-2.0"
xrdb -merge ~/.Xresources
exec openbox-session
EOF
chmod +x ~/.vnc/xstartup

# ── Openbox theme: Arc-Jumpbox ────────────────────────────────────────────────
# Note: font declarations belong in rc.xml only, not themerc.
mkdir -p ~/.themes/Arc-Jumpbox/openbox-3
cat > ~/.themes/Arc-Jumpbox/openbox-3/themerc << 'EOF'
border.width: 1
border.color: #1c1f26

padding.width: 6
padding.height: 5

window.active.border.color: #5294e2
window.inactive.border.color: #1c1f26

window.active.title.bg: flat solid
window.active.title.bg.color: #2f343f
window.active.label.text.color: #d3dae3
window.active.label.bg: parentrelative

window.inactive.title.bg: flat solid
window.inactive.title.bg.color: #262a33
window.inactive.label.text.color: #7c818c
window.inactive.label.bg: parentrelative

window.active.button.unpressed.bg: flat solid
window.active.button.unpressed.bg.color: #2f343f
window.active.button.unpressed.image.color: #d3dae3
window.active.button.hover.bg: flat solid
window.active.button.hover.bg.color: #5294e2
window.active.button.hover.image.color: #ffffff
window.active.button.pressed.bg: flat solid
window.active.button.pressed.bg.color: #4284d4
window.active.button.pressed.image.color: #ffffff

window.inactive.button.unpressed.bg: flat solid
window.inactive.button.unpressed.bg.color: #262a33
window.inactive.button.unpressed.image.color: #7c818c

window.active.handle.bg: flat solid
window.active.handle.bg.color: #5294e2
window.inactive.handle.bg: flat solid
window.inactive.handle.bg.color: #1c1f26
window.active.grip.bg: flat solid
window.active.grip.bg.color: #5294e2
window.inactive.grip.bg: flat solid
window.inactive.grip.bg.color: #1c1f26
handle.width: 2

osd.bg: flat solid
osd.bg.color: #2f343f
osd.border.color: #5294e2
osd.label.text.color: #d3dae3

menu.border.width: 1
menu.border.color: #1c1f26
menu.separator.color: #404552
menu.separator.width: 1
menu.separator.padding.width: 8
menu.separator.padding.height: 4
menu.item.padding.x: 14
menu.item.padding.y: 6

menu.title.bg: flat solid
menu.title.bg.color: #262a33
menu.title.text.color: #5294e2
menu.title.text.justify: left

menu.items.bg: flat solid
menu.items.bg.color: #2f343f
menu.items.text.color: #d3dae3
menu.items.disabled.text.color: #7c818c

menu.items.active.bg: flat solid
menu.items.active.bg.color: #5294e2
menu.items.active.text.color: #ffffff
menu.items.active.disabled.text.color: #a0aab4
EOF

# ── Openbox rc.xml ─────────────────────────────────────────────────────────────
mkdir -p ~/.config/openbox
cat > ~/.config/openbox/rc.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<openbox_config xmlns="http://openbox.org/3.4/rc"
                xmlns:xi="http://www.w3.org/2001/XInclude">

  <resistance>
    <strength>10</strength>
    <screen_edge_strength>20</screen_edge_strength>
  </resistance>

  <focus>
    <focusNew>yes</focusNew>
    <followMouse>no</followMouse>
    <focusLast>yes</focusLast>
    <underMouse>no</underMouse>
    <focusDelay>200</focusDelay>
    <raiseOnFocus>no</raiseOnFocus>
  </focus>

  <placement>
    <policy>Smart</policy>
    <center>yes</center>
    <monitor>Primary</monitor>
    <primaryMonitor>1</primaryMonitor>
  </placement>

  <theme>
    <name>Arc-Jumpbox</name>
    <titleLayout>NLC</titleLayout>
    <keepBorder>yes</keepBorder>
    <animateIconify>no</animateIconify>
    <font place="ActiveWindow">
      <name>Sans</name>
      <size>10</size>
      <weight>Bold</weight>
      <slant>Normal</slant>
    </font>
    <font place="InactiveWindow">
      <name>Sans</name>
      <size>10</size>
      <weight>Normal</weight>
      <slant>Normal</slant>
    </font>
    <font place="MenuHeader">
      <name>Sans</name>
      <size>10</size>
      <weight>Bold</weight>
      <slant>Normal</slant>
    </font>
    <font place="MenuItem">
      <name>Sans</name>
      <size>10</size>
      <weight>Normal</weight>
      <slant>Normal</slant>
    </font>
    <font place="ActiveOnScreenDisplay">
      <name>Sans</name>
      <size>9</size>
      <weight>Bold</weight>
      <slant>Normal</slant>
    </font>
    <font place="InactiveOnScreenDisplay">
      <name>Sans</name>
      <size>9</size>
      <weight>Normal</weight>
      <slant>Normal</slant>
    </font>
  </theme>

  <desktops>
    <number>1</number>
    <firstdesk>1</firstdesk>
    <names><name>Desktop</name></names>
    <popupTime>0</popupTime>
  </desktops>

  <resize>
    <drawContents>yes</drawContents>
    <popupShow>NonPixel</popupShow>
    <popupPosition>Center</popupPosition>
  </resize>

  <!-- Reserve space at the bottom for the tint2 taskbar -->
  <margins>
    <top>0</top><bottom>40</bottom><left>0</left><right>0</right>
  </margins>

  <keyboard>
    <chainQuitKey>C-g</chainQuitKey>
    <keybind key="A-F4">
      <action name="Close"/>
    </keybind>
    <keybind key="A-Tab">
      <action name="NextWindow">
        <finalactions>
          <action name="Focus"/>
          <action name="Raise"/>
          <action name="Unshade"/>
        </finalactions>
      </action>
    </keybind>
  </keyboard>

  <mouse>
    <dragThreshold>8</dragThreshold>
    <doubleClickTime>200</doubleClickTime>
    <screenEdgeWarpTime>0</screenEdgeWarpTime>
    <screenEdgeWarpMouse>false</screenEdgeWarpMouse>
    <context name="Frame">
      <mousebind button="A-Left" action="Press">
        <action name="Focus"/><action name="Raise"/><action name="Move"/>
      </mousebind>
      <mousebind button="A-Right" action="Press">
        <action name="Focus"/><action name="Raise"/><action name="Resize"/>
      </mousebind>
    </context>
    <context name="Titlebar">
      <mousebind button="Left" action="Drag">
        <action name="Move"/>
      </mousebind>
      <mousebind button="Left" action="DoubleClick">
        <action name="ToggleMaximizeFull"/>
      </mousebind>
    </context>
    <context name="Titlebar Top Right Bottom Left TLCorner TRCorner BRCorner BLCorner">
      <mousebind button="Left" action="Press">
        <action name="Focus"/><action name="Raise"/><action name="Unshade"/>
      </mousebind>
    </context>
    <context name="Desktop">
      <mousebind button="Right" action="Press">
        <action name="ShowMenu"><menu>root-menu</menu></action>
      </mousebind>
    </context>
    <context name="BLCorner BRCorner">
      <mousebind button="Left" action="Drag">
        <action name="Resize"/>
      </mousebind>
    </context>
  </mouse>

  <menu>
    <file>menu.xml</file>
    <hideDelay>200</hideDelay>
    <middle>no</middle>
    <submenuShowDelay>100</submenuShowDelay>
    <submenuHideDelay>400</submenuHideDelay>
    <applicationIcons>no</applicationIcons>
    <manageDesktops>no</manageDesktops>
  </menu>

  <applications/>

</openbox_config>
EOF

# ── Openbox menu.xml ───────────────────────────────────────────────────────────
cat > ~/.config/openbox/menu.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<openbox_menu xmlns="http://openbox.org/3.4/menu">
  <menu id="root-menu" label="Jumpbox">
    <item label="Terminal">
      <action name="Execute"><command>xterm</command></action>
    </item>
    <item label="Firefox">
      <action name="Execute"><command>firefox</command></action>
    </item>
    <item label="VS Code">
      <action name="Execute"><command>code --no-sandbox --disable-gpu</command></action>
    </item>
    <item label="Claude Desktop">
      <action name="Execute"><command>claude-desktop --no-sandbox</command></action>
    </item>
    <separator/>
    <item label="Reconfigure Openbox">
      <action name="Reconfigure"/>
    </item>
  </menu>
</openbox_menu>
EOF

# ── Openbox autostart: desktop background + taskbar only ──────────────────────
cat > ~/.config/openbox/autostart << 'EOF'
xsetroot -solid "#2b303b" &
tint2 &
EOF

# ── tint2 taskbar config (Arc-Dark) ────────────────────────────────────────────
mkdir -p ~/.config/tint2
cat > ~/.config/tint2/tint2rc << 'EOF'
# --- tint2 config: Arc-Dark taskbar ---

# Panel
panel_items = TSC
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
task_width = 200
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

# ── Xresources: dark xterm (Arc-Dark palette) ──────────────────────────────────
cat > ~/.Xresources << 'EOF'
XTerm*background:           #2f343f
XTerm*foreground:           #d3dae3
XTerm*cursorColor:          #5294e2
XTerm*color0:               #3b4048
XTerm*color1:               #cc575d
XTerm*color2:               #8bc34a
XTerm*color3:               #f9a825
XTerm*color4:               #5294e2
XTerm*color5:               #9c71c7
XTerm*color6:               #26a69a
XTerm*color7:               #d3dae3
XTerm*color8:               #404552
XTerm*color9:               #f05b5b
XTerm*color10:              #9ccc65
XTerm*color11:              #fbc02d
XTerm*color12:              #72a4f7
XTerm*color13:              #b39ddb
XTerm*color14:              #4db6ac
XTerm*color15:              #ffffff
XTerm*faceName:             monospace
XTerm*faceSize:             11
XTerm*scrollBar:            false
XTerm*saveLines:            10000
XTerm*selectToClipboard:    true
XTerm*bellIsUrgent:         false
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
