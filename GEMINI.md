# NordVPN Proxy Project Overview

This project provides a Dockerized implementation of the official NordVPN Linux client, functioning as a network gateway. It exposes both an HTTP proxy (via Privoxy) and a SOCKS5 proxy (via Gost), allowing local devices to route traffic through a secure NordVPN tunnel (NordLynx) without affecting the host machine's network.

## Architecture & Technology Stack
- **Base OS**: Ubuntu 22.04
- **VPN Client**: Official NordVPN Linux App (Native)
- **Protocols**: NordLynx (WireGuard-based)
- **Proxies**: 
  - **HTTP**: Privoxy (Port 8118)
  - **SOCKS5**: Gost (Port 1080) - High-performance proxy with full TCP/UDP support.
- **Key Logic**: A robust `entrypoint.sh` script that handles daemon initialization, token-based login, local network whitelisting, and a "Proactive Unlock" mechanism for `resolv.conf`.
- **Config Persistence**: A `/config` directory is exposed as a volume, allowing users to persist and modify Privoxy (within `/config/privoxy/`) and Gost (`gost.json`) configurations locally.
- **Permission Management**: Supports `PUID`, `PGID`, and `UMASK` to ensure file ownership and permissions are compatible with the host system (especially Unraid).

## Key Files
- `Dockerfile`: Configures the environment, installs dependencies (including Gost), and sets up the NordVPN repository.
- `entrypoint.sh`: The heart of the container. Manages the lifecycle, fixes DNS locking issues, monitors the VPN connection, handles permissions/UMASK, and seeds default configurations to the `/config` volume.
- `privoxy/`: Directory containing modular Privoxy configuration files (`config`, `user.action`, etc.).
- `gost.json`: Default configuration for the SOCKS5 proxy (Gost).
- `docker-compose.yml`: Provides a ready-to-use deployment template with volume mapping for config persistence.
- `README.md`: End-user documentation for setup and Unraid integration.

## Building and Running

### Build
To build the image locally:
```bash
docker build -t dhovin/nordvpn-proxy:latest .
```

### Run
To start the container using Docker Compose:
```bash
docker-compose up -d
```

### Testing
- **HTTP**: `curl.exe -x http://[HOST_IP]:[8118] https://ipapi.co/json/`
- **SOCKS5**: `curl.exe --socks5-hostname [HOST_IP]:[1080] https://ipapi.co/json/`

## Development Conventions
- **Versioning**: Incremental versions are noted in the `entrypoint.sh` startup message (Current: v26).
- **DNS Handling**: Uses a "Proactive Unlock" strategy (`chattr -i /etc/resolv.conf`) to prevent the NordVPN app from permanently locking the host-mapped DNS files.

- **SOCKS5 Engine**: Powered by Gost for its robust handling of UDP Associate and remote DNS resolution, which are critical for modern web applications and media loading.
- **Network Visibility**: Relies on the `NETWORK` environment variable to dynamically whitelist local subnets in both the NordVPN firewall and Privoxy.
- **Permissions**: Requires `privileged: true` and `NET_ADMIN` capabilities to manage network interfaces and iptables.

## Usage in Unraid
- **Repository**: `dhovin/nordvpn-proxy:latest`
- **Network**: Bridge
- **Privileged**: OFF (Recommended for security)
- **Extra Parameters**: `--cap-add=NET_ADMIN`
- **Variables**: `NORDVPN_TOKEN` (Required), `CONNECT` (Default: Canada), `NETWORK` (e.g., 192.168.1.0/24).
- **Devices**: `/dev/net/tun` must be passed through.

## Usage in TrueNAS SCALE
- **Image**: `dhovin/nordvpn-proxy:latest`
- **Capabilities**: Add `NET_ADMIN`.
- **Devices**: Map host `/dev/net/tun` to container `/dev/net/tun`.
- **Variables**: Same as Unraid.
