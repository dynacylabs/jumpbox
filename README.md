# jumpbox

A browser-accessible desktop in a Docker container. Runs Firefox, VS Code, Claude Desktop, and a terminal — accessible from any browser via noVNC.

Works on both **amd64** (Linux/Windows) and **arm64** (Apple Silicon).

## What's inside

| Component | Purpose |
|---|---|
| Ubuntu 24.04 | Base OS |
| XFCE4 | Desktop environment (panel, window manager, compositor) |
| xfce4-terminal | Terminal emulator |
| Plank | Application dock |
| Firefox | Web browser (native `.deb` via mozillateam PPA) |
| VS Code | Editor |
| Claude Desktop | AI assistant |
| TigerVNC | X11 VNC server |
| noVNC + websockify | Browser-based VNC client, no plugin needed |

## Requirements

- Docker & Docker Compose

## Setup

Create a `.env` file with your password:

```bash
cat > .env << 'EOF'
VNC_PASSWORD=yourpassword
VNC_GEOMETRY=1920x1080
NOVNC_PORT=6080
EOF
```

## Usage

```bash
docker compose up --build -d
```

Open in your browser:

```
http://localhost:6080/vnc.html
```

Enter the VNC password when prompted. Firefox, VS Code, and a terminal will launch automatically inside the session.

To stop:

```bash
docker compose down
```

## Persistence

The container runs with an internal home directory. Data inside the container does not persist across image rebuilds or container recreation unless you add your own bind mounts.

## Configuration

| Variable | Default | Description |
|---|---|---|
| `VNC_PASSWORD` | `changeme` | Password required to connect via noVNC |
| `VNC_GEOMETRY` | `1920x1080` | Desktop resolution |
| `NOVNC_PORT` | `6080` | Host port the web interface is exposed on |

## Extra packages

Add extra apt packages directly in the main `apt-get install -y` list in `Dockerfile`.

After editing `Dockerfile`, rebuild and recreate:

```bash
docker compose build --no-cache
docker compose up -d --force-recreate
```

## Deploying with Portainer

Portainer cannot build images from source — build and tag the image on the Docker host first:

```bash
git clone https://github.com/dynacylabs/jumpbox.git
cd jumpbox
docker build -t jumpbox:latest .
```

In Portainer → **Stacks → Add stack**, paste the following and set the environment variables in the panel below the editor:

```yaml
services:
  jumpbox:
    image: jumpbox:latest
    container_name: jumpbox
    restart: unless-stopped
    shm_size: '2gb'
    ports:
      - "${NOVNC_PORT:-6080}:6080"
    environment:
      - VNC_PASSWORD=${VNC_PASSWORD:-changeme}
      - VNC_GEOMETRY=${VNC_GEOMETRY:-1920x1080}
```

## Adding apps to the dock

To pin a custom program (e.g. one you launch with `./program`) to the Plank dock:

**1. Create a `.desktop` file** — use the full absolute path to the binary:

```bash
mkdir -p ~/.local/share/applications
cat > ~/.local/share/applications/myapp.desktop << 'EOF'
[Desktop Entry]
Name=My App
Comment=Short description
Exec=/full/path/to/program
Icon=application-x-executable
Type=Application
Categories=Utility;
EOF
```

**2. Create a dockitem** pointing to that file:

```bash
cat > ~/.config/plank/dock1/launchers/myapp.dockitem << 'EOF'
[PlankDockItemPreferences]
Launcher=file:///home/user/.local/share/applications/myapp.desktop
EOF
```

**3. Reload Plank:**

```bash
pkill plank && plank &
```

> **Tip:** If the app is already running, right-click its dock icon and choose **Keep in Dock** — no files needed.
