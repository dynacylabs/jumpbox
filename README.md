# jumpbox

A minimal browser-accessible desktop in a Docker container. Runs Firefox, VS Code, and a terminal — nothing else — accessible from any browser via noVNC.

Works on both **amd64** (Linux/Windows) and **arm64** (Apple Silicon).

## What's inside

| Component | Purpose |
|---|---|
| Ubuntu 24.04 | Base image (minimal rootfs, no desktop environment) |
| Openbox | Bare window manager — just enough to manage windows |
| Firefox | Web browser (native `.deb` via mozillateam PPA) |
| VS Code | Editor |
| xterm | Terminal |
| TigerVNC | X11 VNC server |
| noVNC + websockify | Browser-based VNC client, no plugin needed |

## Requirements

- Docker & Docker Compose

## Setup

```bash
cp .env.example .env
```

Edit `.env` and set a real password:

```
VNC_PASSWORD=yourpassword
VNC_GEOMETRY=1920x1080
NOVNC_PORT=6080
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

The container's home directory is mounted to `./data/home`. VS Code settings, extensions, Firefox profiles, and any files saved in the home directory survive container restarts and rebuilds.

## Configuration

| Variable | Default | Description |
|---|---|---|
| `VNC_PASSWORD` | `changeme` | Password required to connect via noVNC |
| `VNC_GEOMETRY` | `1920x1080` | Desktop resolution |
| `NOVNC_PORT` | `6080` | Host port the web interface is exposed on |
