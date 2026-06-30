FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV USER=user
ENV HOME=/home/user

# ── System deps ────────────────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    ca-certificates \
    gnupg \
    sudo \
    dbus-x11 \
    xdg-utils \
    xfce4 \
    xfce4-terminal \
    xfce4-goodies \
    fonts-liberation \
    software-properties-common \
    tigervnc-standalone-server \
    novnc \
    python3-websockify \
    x11-xserver-utils \
    arc-theme \
    papirus-icon-theme \
    picom \
    plank \
    && rm -rf /var/lib/apt/lists/*

# ── Firefox (Mozilla Team PPA – native .deb, supports amd64 + arm64) ──────────
# Pin PPA above Ubuntu's snap redirect so apt installs the real .deb package.
RUN add-apt-repository -y ppa:mozillateam/ppa \
    && printf 'Package: *\nPin: release o=LP-PPA-mozillateam\nPin-Priority: 1001\n' \
         > /etc/apt/preferences.d/mozilla-firefox \
    && apt-get update \
    && apt-get install -y firefox \
    && rm -rf /var/lib/apt/lists/*

# ── VS Code (amd64 + arm64) ────────────────────────────────────────────────────
RUN wget -qO- https://packages.microsoft.com/keys/microsoft.asc \
        | gpg --dearmor > /usr/share/keyrings/microsoft.gpg \
    && ARCH=$(dpkg --print-architecture) \
    && echo "deb [arch=${ARCH} signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
         > /etc/apt/sources.list.d/vscode.list \
    && apt-get update \
    && apt-get install -y code \
    && rm -rf /var/lib/apt/lists/*

# ── Claude Desktop (amd64 + arm64) ────────────────────────────────────────────
# Official Anthropic Linux packages were removed; use aaddrick/claude-desktop-debian
# (community repackage, updated automatically on each Claude Desktop release).
RUN ARCH=$(dpkg --print-architecture) \
    && apt-get update \
    && wget -qO /tmp/gh-release.json \
         "https://api.github.com/repos/aaddrick/claude-desktop-debian/releases/latest" \
    && DEB_URL=$(python3 -c "
import json, sys
arch = sys.argv[1]
with open('/tmp/gh-release.json') as f:
    data = json.load(f)
for a in data['assets']:
    if a['name'].endswith('_' + arch + '.deb'):
        print(a['browser_download_url'])
        break
" "$ARCH") \
    && wget -qO /tmp/claude-desktop.deb "$DEB_URL" \
    && apt-get install -y /tmp/claude-desktop.deb \
    && rm -f /tmp/claude-desktop.deb /tmp/gh-release.json \
    && rm -rf /var/lib/apt/lists/*

# ── Non-root user ──────────────────────────────────────────────────────────────
RUN useradd -m -s /bin/bash "$USER" \
    && usermod -aG sudo "$USER" \
    && echo "$USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/user \
    && chmod 440 /etc/sudoers.d/user

# ── Container script ───────────────────────────────────────────────────────────
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 6080

USER $USER
WORKDIR $HOME
ENTRYPOINT ["/entrypoint.sh"]
