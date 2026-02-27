#!/bin/bash

# Pre-flight check
if [ -z "$NORDVPN_TOKEN" ]; then
    echo "--- FATAL ERROR ---"
    echo "NORDVPN_TOKEN environment variable is missing!"
    sleep 300
    exit 1
fi

# 1. IMMEDIATE HOST-LEVEL FIX
# Clear any locks from previous crashes before doing anything else
chattr -i /etc/resolv.conf 2>/dev/null || true

cleanup() {
    echo "Container stopping, performing graceful disconnect..."
    nordvpn disconnect 2>/dev/null || true
    chattr -i /etc/resolv.conf 2>/dev/null || true
    exit 0
}
trap cleanup SIGINT SIGTERM EXIT

COUNTRY=${CONNECT:-Canada}
GROUP=${GROUP:-""}
NETWORK=$(echo "${NETWORK:-192.168.0.0/16,172.16.0.0/12,10.0.0.0/8}" | tr -d ' ')

echo "--- NordVPN Docker Startup (v19 - Proactive Unlock) ---"

# 2. DAEMON PREP
# Ensure clean socket/pid environment
rm -rf /run/nordvpn /var/run/nordvpn 2>/dev/null || true
mkdir -p /run/nordvpn /var/run/nordvpn 2>/dev/null || true

# Start daemon
/usr/sbin/nordvpnd &

echo "Waiting for NordVPN socket..."
MAX_RETRIES=20
COUNT=0
while [ ! -S /run/nordvpn/nordvpnd.sock ] && [ $COUNT -lt $MAX_RETRIES ]; do
    sleep 1
    COUNT=$((COUNT + 1))
done
sleep 2

echo "Applying Protection..."
nordvpn set dns off || true
nordvpn set technology nordlynx || true
nordvpn set killswitch on || true
nordvpn set lan-discovery on || true

# Set DNS
echo "nameserver 103.86.96.100" > /etc/resolv.conf
echo "nameserver 103.86.99.100" >> /etc/resolv.conf

echo "Logging in..."
nordvpn login --token "$NORDVPN_TOKEN"

echo "Whitelisting local networks..."
nordvpn whitelist add subnet 127.0.0.1/32 || true
nordvpn whitelist add subnet 172.16.0.0/12 || true 
nordvpn whitelist add subnet 192.168.0.0/16 || true
nordvpn whitelist add subnet 10.0.0.0/8 || true

IFS=',' read -ra ADDR <<< "$NETWORK"
for i in "${ADDR[@]}"; do
    nordvpn whitelist add subnet "$i" || true
done

# Configure Privoxy
echo "Configuring Privoxy..."
sed -i '/^permit-access/d' /etc/privoxy/config
echo "permit-access 127.0.0.1" >> /etc/privoxy/config
echo "permit-access 172.16.0.0/12" >> /etc/privoxy/config
echo "permit-access 10.0.0.0/8" >> /etc/privoxy/config
echo "permit-access 192.168.0.0/16" >> /etc/privoxy/config
for i in "${ADDR[@]}"; do
    echo "permit-access $i" >> /etc/privoxy/config
done

echo "Connecting to $COUNTRY..."
if [ -n "$GROUP" ]; then
    nordvpn connect "$COUNTRY" "$GROUP"
else
    nordvpn connect "$COUNTRY"
fi

# Detect Interface
VPN_IFACE=""
COUNT=0
while [ -z "$VPN_IFACE" ] && [ $COUNT -lt 30 ]; do
    VPN_IFACE=$(ip addr show | grep -E 'nordlynx|tun0' | awk -F': ' '{print $2}' | cut -d'@' -f1 | head -n1)
    [ -z "$VPN_IFACE" ] && sleep 1 && COUNT=$((COUNT + 1))
done

if [ -z "$VPN_IFACE" ]; then
    echo "ERROR: No VPN interface detected."
    sleep 300
    exit 1
fi

# 3. THE MAGIC FIX
# Now that we are connected, NordVPN has already tried to lock the file.
# We unlock it IMMEDIATELY so it's safe if we crash.
echo "Unlocking resolv.conf for host safety..."
chattr -i /etc/resolv.conf 2>/dev/null || true

echo "--- VPN Connected ($VPN_IFACE) ---"
nordvpn status

echo "Starting Proxies..."
privoxy --no-daemon /etc/privoxy/config &
microsocks -i 0.0.0.0 -p 1080 &

echo "System Ready."

# Monitor
while true; do
    # Continuously unlock resolv.conf every minute just in case the app relocks it
    chattr -i /etc/resolv.conf 2>/dev/null || true
    
    if ! ip addr show "$VPN_IFACE" > /dev/null 2>&1; then
        echo "VPN Lost. Reconnecting..."
        if [ -n "$GROUP" ]; then
            nordvpn connect "$COUNTRY" "$GROUP"
        else
            nordvpn connect "$COUNTRY"
        fi
        sleep 10
        chattr -i /etc/resolv.conf 2>/dev/null || true
    fi
    sleep 60
done
