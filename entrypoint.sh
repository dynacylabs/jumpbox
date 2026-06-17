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
cat > ~/.vnc/xstartup << 'EOF'
#!/bin/bash
export GTK_THEME=Arc-Dark
export GTK2_RC_FILES="$HOME/.gtkrc-2.0"
xrdb -merge ~/.Xresources
exec dbus-launch --exit-with-session openbox-session
EOF
chmod +x ~/.vnc/xstartup

# ── Openbox config (always recreated to avoid stale volume state) ───────────────
rm -rf ~/.config/openbox
mkdir -p ~/.config/openbox

# ── Custom Openbox theme (self-contained, no dependency on arc-theme) ─────────
# Written directly into ~/.themes so it is always available regardless of what
# system packages provide.
mkdir -p ~/.themes/Jumpbox/openbox-3
cat > ~/.themes/Jumpbox/openbox-3/themerc << 'EOF'
# Jumpbox — minimal dark theme, flat design
border.width: 1
border.color: #181818

padding.width: 8
padding.height: 7

# Active window
window.active.border.color: #5294e2
window.inactive.border.color: #1e1e1e

window.active.title.bg: flat solid
window.active.title.bg.color: #1e1e1e
window.active.label.text.color: #e0e0e0
window.active.label.bg: parentrelative

window.inactive.title.bg: flat solid
window.inactive.title.bg.color: #161616
window.inactive.label.text.color: #555555
window.inactive.label.bg: parentrelative

# Buttons — all buttons (normal state)
window.active.button.unpressed.bg: flat solid
window.active.button.unpressed.bg.color: #1e1e1e
window.active.button.unpressed.image.color: #9e9e9e

# Hover — accent blue
window.active.button.hover.bg: flat solid
window.active.button.hover.bg.color: #5294e2
window.active.button.hover.image.color: #ffffff

# Pressed
window.active.button.pressed.bg: flat solid
window.active.button.pressed.bg.color: #3a7bc8
window.active.button.pressed.image.color: #ffffff

# Inactive buttons
window.inactive.button.unpressed.bg: flat solid
window.inactive.button.unpressed.bg.color: #161616
window.inactive.button.unpressed.image.color: #3a3a3a

# No resize handle (clean look)
handle.width: 0

# OSD (alt-tab)
osd.bg: flat solid
osd.bg.color: #1e1e1e
osd.border.color: #5294e2
osd.border.width: 1
osd.label.text.color: #e0e0e0

# Right-click menu
menu.border.width: 1
menu.border.color: #181818
menu.separator.color: #333333
menu.separator.width: 1
menu.separator.padding.width: 6
menu.separator.padding.height: 3
menu.item.padding.x: 14
menu.item.padding.y: 6

menu.title.bg: flat solid
menu.title.bg.color: #161616
menu.title.text.color: #5294e2
menu.title.text.justify: left

menu.items.bg: flat solid
menu.items.bg.color: #1e1e1e
menu.items.text.color: #e0e0e0
menu.items.disabled.text.color: #555555

menu.items.active.bg: flat solid
menu.items.active.bg.color: #5294e2
menu.items.active.text.color: #ffffff
menu.items.active.disabled.text.color: #9e9e9e
EOF

# ── rc.xml ─────────────────────────────────────────────────────────────────────
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
    <name>Jumpbox</name>
    <!-- NL|IMC = [icon][label] ... [minimize][maximize][close] -->
    <titleLayout>NL|IMC</titleLayout>
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
          <action name="Focus"/><action name="Raise"/><action name="Unshade"/>
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
      <mousebind button="Left" action="Press">
        <action name="Focus"/><action name="Raise"/>
      </mousebind>
      <mousebind button="Left" action="Drag">
        <action name="Move"/>
      </mousebind>
      <mousebind button="Left" action="DoubleClick">
        <action name="ToggleMaximizeFull"/>
      </mousebind>
    </context>

    <!-- Explicit button bindings so close/max/min always work -->
    <context name="Close">
      <mousebind button="Left" action="Click">
        <action name="Close"/>
      </mousebind>
    </context>
    <context name="Maximize">
      <mousebind button="Left" action="Click">
        <action name="ToggleMaximizeFull"/>
      </mousebind>
    </context>
    <context name="Iconify">
      <mousebind button="Left" action="Click">
        <action name="Iconify"/>
      </mousebind>
    </context>

    <context name="Top">
      <mousebind button="Left" action="Drag">
        <action name="Resize"><edge>top</edge></action>
      </mousebind>
    </context>
    <context name="Bottom">
      <mousebind button="Left" action="Drag">
        <action name="Resize"><edge>bottom</edge></action>
      </mousebind>
    </context>
    <context name="Left">
      <mousebind button="Left" action="Drag">
        <action name="Resize"><edge>left</edge></action>
      </mousebind>
    </context>
    <context name="Right">
      <mousebind button="Left" action="Drag">
        <action name="Resize"><edge>right</edge></action>
      </mousebind>
    </context>
    <context name="BLCorner BRCorner TLCorner TRCorner">
      <mousebind button="Left" action="Drag">
        <action name="Resize"/>
      </mousebind>
    </context>

    <context name="Desktop">
      <mousebind button="Right" action="Press">
        <action name="ShowMenu"><menu>root-menu</menu></action>
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

# Right-click desktop menu
cat > ~/.config/openbox/menu.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<openbox_menu xmlns="http://openbox.org/3.4/menu">
  <menu id="root-menu" label="Jumpbox">
    <item label="Terminal">
      <action name="Execute"><command>xfce4-terminal</command></action>
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

# Autostart: background + compositor + taskbar
cat > ~/.config/openbox/autostart << 'EOF'
xsetroot -solid "#141414" &
picom --daemon --backend xrender --corner-radius 10 --shadow --shadow-radius 18 --shadow-opacity 0.5 --shadow-offset-x -12 --shadow-offset-y -12 --no-fading-openclose &
tint2 &
EOF

# ── picom config ───────────────────────────────────────────────────────────────
mkdir -p ~/.config/picom
cat > ~/.config/picom/picom.conf << 'EOF'
backend = "xrender";
corner-radius = 10;
rounded-corners-exclude = [
  "window_type = 'dock'",
  "window_type = 'desktop'",
  "window_type = 'menu'",
  "window_type = 'popup_menu'",
  "window_type = 'dropdown_menu'"
];
shadow = true;
shadow-radius = 18;
shadow-opacity = 0.5;
shadow-offset-x = -12;
shadow-offset-y = -12;
shadow-exclude = [
  "window_type = 'dock'",
  "window_type = 'tooltip'",
  "window_type = 'menu'"
];
fading = false;
EOF

# ── tint2 taskbar: launchers + tasks + tray + clock ───────────────────────────
mkdir -p ~/.config/tint2
cat > ~/.config/tint2/tint2rc << 'EOF'
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
background_color = #1e1e1e 100
border_color = #1e1e1e 0

rounded = 0
border_width = 1
background_color = #2d2d2d 100
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
taskbar_name_font_color = #bbbbbb 100
taskbar_name_active_font_color = #ffffff 100
taskbar_distribute_size = 0
taskbar_sort_order = none
task_align = left

task_text = 1
task_icon = 1
task_centered = 1
task_tooltip = 1
urgent_nb_of_blink = 8
task_width = 180
task_height = 36
task_padding = 6 3 6
task_font = Sans 10
task_font_color = #bbbbbb 85
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
clock_font_color = #bbbbbb 100
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

# ── xfce4-terminal ────────────────────────────────────────────────────────────
mkdir -p ~/.config/xfce4/terminal
cat > ~/.config/xfce4/terminal/terminalrc << 'EOF'
[Configuration]
FontName=Monospace 11
ColorBackground=#1e1e1e
ColorForeground=#d4d4d4
ColorCursor=#5294e2
ColorPalette=#1e1e1e;#f44747;#608b4e;#dcdcaa;#569cd6;#c678dd;#56b6c2;#d4d4d4;#808080;#f44747;#608b4e;#dcdcaa;#569cd6;#c678dd;#56b6c2;#ffffff
MiscShowUnsafePasteDialog=FALSE
ScrollingUnlimited=TRUE
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

exec websockify --web /usr/share/novnc/ 6080 localhost:5901
