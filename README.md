# NordVPN Proxy Docker for Unraid

This Docker container runs the native NordVPN Linux app and provides both HTTP (Privoxy) and SOCKS5 (Gost) proxies. All traffic through these proxies is routed via the VPN.

## Features
- **Native NordVPN app**: Supports NordLynx and autoconnect.
- **Dual Proxy**: HTTP (8118) and SOCKS5 (1080).
- **SOCKS5 UDP Support**: Uses **Gost** for robust TCP and UDP traffic handling.
- **DNS Leak Protection**: Forced usage of NordVPN private DNS.
- **Connection Logging**: Prints IP and location info to the Docker log on startup.
- **Auto-Update**: Optionally keeps the NordVPN client up to date.

## Setup Instructions

### 1. Get a NordVPN Token
1. Go to your [NordVPN Account dashboard](https://my.nordaccount.com/).
2. Navigate to **Services > NordVPN**.
3. Scroll down to **Access Token** and click **Generate new token**.
4. Choose "Never expire" (or your preferred duration) and copy the token.

### 2. Configuration (Environment Variables)
- `NORDVPN_TOKEN`: Your NordVPN access token (Required).
- `CONNECT`: The country to connect to (Default: `Canada`).
- `NETWORK`: Your local subnet(s) allowed to use the proxy (Default: `192.168.0.0/16,172.16.0.0/12,10.0.0.0/8`).
- `AUTO_UPDATE`: Set to `true` to update the NordVPN app on startup.
- `GROUP`: Optional NordVPN group (e.g., `Double_VPN`).
- `PUID`: User ID for file ownership (Unraid default: `99`).
- `PGID`: Group ID for file ownership (Unraid default: `100`).
- `UMASK`: Sets file creation permissions. 
    - `022` (Default): Owner can write, others can only read.
    - `000`: Full read/write/execute permissions for everyone (**777**). Useful for avoiding permission issues in Unraid.

### 3. Configuration Persistence (Optional)
You can now persist and modify the proxy configurations by mounting a local directory to `/config`.
- `/config/privoxy.config`: The main Privoxy configuration file.
- `/config/*.action`: Privoxy action files (e.g., `user.action`).
- `/config/*.filter`: Privoxy filter files.
- `/config/gost.json`: The Gost configuration file (SOCKS5 settings).

When you first run the container with a volume mounted to `/config`, it will automatically seed these files with default settings if they are missing.

### 4. Bypassing CDN/Cloudflare Issues
If you encounter issues with Cloudflare-protected sites or CDNs (images not loading, connection errors), you can modify `/config/user.action`.
1. Open `user.action` in your editor.
2. The file is structured into **Tier 1 (Infrastructure)** and **Tier 2 (General CDNs)**.
3. These tiers use the `fragile` alias to disable aggressive filtering and cookie crunching for problematic domains.
4. Add or remove domains under the appropriate section as needed.
5. Restart the container to apply changes.

### 4. Running with Docker Compose
```yaml
services:
  nordvpn-proxy:
    image: dhovin/nordvpn-proxy:latest
    container_name: nordvpn-proxy
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/net/tun:/dev/net/tun
    environment:
      - NORDVPN_TOKEN=your_token_here
      - CONNECT=Canada
      - NETWORK=192.168.1.0/24
      - AUTO_UPDATE=true
    volumes:
      - ./config:/config
    ports:
      - "8118:8118"
      - "1080:1080"
    restart: unless-stopped
```

### 5. Setup in Unraid
If you are adding this manually in Unraid:
1. **Repository**: `dhovin/nordvpn-proxy:latest`
2. **Network Type**: `Bridge`
3. **Privileged**: `Off` (Recommended for better security)
4. **Extra Parameters**: `--cap-add=NET_ADMIN --sysctl net.ipv6.conf.all.disable_ipv6=1`
5. **Port 8118**: HTTP Proxy (Host: 8118, Container: 8118)
6. **Port 1080**: SOCKS5 Proxy (Host: 1080, Container: 1080)
7. **Variable NORDVPN_TOKEN**: Paste your access token.
8. **Variable CONNECT**: Set your country (e.g., `Canada`).
9. **Variable NETWORK**: Set your local subnet (e.g., `192.168.10.0/24`).
10. **Variable AUTO_UPDATE**: Set to `true` to keep NordVPN current.
11. **Device**: Map `/dev/net/tun` to `/dev/net/tun`.

### 6. Setup in TrueNAS SCALE (Custom App)
If you are using the "Custom App" wizard in TrueNAS SCALE:
1. **Application Name**: `nordvpn-proxy`
2. **Container Image**: `dhovin/nordvpn-proxy:latest`
3. **Environment Variables**:
   - `NORDVPN_TOKEN`: (Your Token)
   - `CONNECT`: `Canada`
   - `NETWORK`: (Your home subnet, e.g., `192.168.1.0/24`)
4. **Networking**:
   - Add Port Forwarding for `8118` (HTTP) and `1080` (SOCKS5).
5. **Security Context** (Very Important):
   - **Privileged Mode**: `Off`
   - **Add Capabilities**: `NET_ADMIN`
6. **Storage / Devices**:
   - Add a "Host Path" for `/dev/net/tun` mapped to `/dev/net/tun` inside the container.
7. **Sysctls** (Advanced):
   - Add `net.ipv6.conf.all.disable_ipv6=1` if the UI allows it, or use the `AUTO_UPDATE` variable to ensure the script handles it internally.

## Usage
- **HTTP Proxy**: Set your browser or app to use `[Server-IP]:8118`.
- **SOCKS5 Proxy**: 
  1. Set your browser or app to use `[Server-IP]:1080`.
  2. **Crucial (Firefox)**: In Settings -> Network Settings, ensure **"Proxy DNS when using SOCKS v5"** is **CHECKED**. This ensures images and media load correctly by preventing DNS mismatches.

## Notes
- The container uses `net.ipv6.conf.all.disable_ipv6=1` to prevent IPv6 leaks.
- Local network subnets are managed via the `NETWORK` environment variable to ensure proxy and VPN accessibility.
