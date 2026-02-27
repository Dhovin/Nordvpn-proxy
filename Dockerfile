FROM ubuntu:22.04

# Install dependencies
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    ca-certificates \
    gnupg \
    iproute2 \
    iptables \
    privoxy \
    microsocks \
    dos2unix \
    e2fsprogs \
    net-tools \
    && rm -rf /var/lib/apt/lists/*

# Install NordVPN
RUN wget -qO - https://repo.nordvpn.com/gpg/nordvpn_public.asc | gpg --dearmor > /usr/share/keyrings/nordvpn-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/nordvpn-keyring.gpg] https://repo.nordvpn.com/deb/nordvpn/debian stable main" > /etc/apt/sources.list.d/nordvpn.list \
    && apt-get update && apt-get install -y nordvpn \
    && rm -rf /var/lib/apt/lists/*

# Copy configuration files
COPY entrypoint.sh /entrypoint.sh
COPY privoxy.config /etc/privoxy/config

# Fix Windows line endings and set permissions
RUN dos2unix /entrypoint.sh && chmod +x /entrypoint.sh

# Privoxy port
EXPOSE 8118
# Microsocks (SOCKS5) port
EXPOSE 1080

ENTRYPOINT ["/entrypoint.sh"]
