FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# 1. Install prerequisites & setup NordVPN repository
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    curl \
    ca-certificates \
    gnupg \
    && wget -qO - https://repo.nordvpn.com/gpg/nordvpn_public.asc | gpg --dearmor > /usr/share/keyrings/nordvpn-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/nordvpn-keyring.gpg] https://repo.nordvpn.com/deb/nordvpn/debian stable main" > /etc/apt/sources.list.d/nordvpn.list \
    && apt-get update && apt-get install -y --no-install-recommends \
    iproute2 \
    iptables \
    privoxy \
    dos2unix \
    e2fsprogs \
    net-tools \
    iputils-ping \
    dbus \
    nordvpn \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# 2. Install Gost (SOCKS5 with UDP support) - auto-detects architecture (amd64 / arm64 / armv7)
RUN ARCH="$(dpkg --print-architecture)" && \
    case "${ARCH}" in \
      amd64) GOST_ARCH="amd64" ;; \
      arm64) GOST_ARCH="arm64" ;; \
      armhf) GOST_ARCH="armv7" ;; \
      *) GOST_ARCH="amd64" ;; \
    esac && \
    wget -qO- "https://github.com/ginuerzh/gost/releases/download/v2.11.5/gost-linux-${GOST_ARCH}-2.11.5.gz" | gunzip > /usr/local/bin/gost \
    && chmod +x /usr/local/bin/gost

# 3. Copy configuration files & prepare entrypoint
COPY entrypoint.sh /entrypoint.sh
COPY privoxy/ /etc/privoxy/
COPY gost.json /etc/gost/gost.json

RUN dos2unix /entrypoint.sh && chmod +x /entrypoint.sh

# Config Volume
VOLUME /config

# Expose HTTP (Privoxy) and SOCKS5 (Gost) ports
EXPOSE 8118 1080

# Healthcheck for container monitoring
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
  CMD curl -s -f http://127.0.0.1:8118/ > /dev/null || exit 1

ENTRYPOINT ["/entrypoint.sh"]

