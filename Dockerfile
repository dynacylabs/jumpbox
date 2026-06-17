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
    openbox \
    xterm \
    fonts-liberation \
    software-properties-common \
    tigervnc-standalone-server \
    novnc \
    python3-websockify \
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
