#!/bin/bash
# Toggle Bitcoin Core Tor mode
# Usage: ./toggle-tor.sh [on|mixed|off]
#   on    = Onion peers only (most private)
#   mixed = Both onion + clearnet peers (more peers, faster)
#   off   = Clearnet only (fastest, routed through VPN if VPN is on)
#
# When VPN is on:
#   Clearnet peers → VPN SOCKS proxy (172.28.0.20:1080) → WireGuard → Internet
#   Onion peers    → Tor SOCKS (172.28.0.10:9050) → Tor network → Internet
#   Two independent pipes. Tor does NOT go through VPN.

set -euo pipefail
cd "$(dirname "$0")"

CONF="bitcoin.conf"
VPN_ON=false
[ -f .vpn-mode ] && VPN_ON=true

TOR_PROXY="172.28.0.10:9050"
VPN_PROXY="172.28.0.20:1080"

if [ $# -ne 1 ] || [[ "$1" != "on" && "$1" != "mixed" && "$1" != "off" ]]; then
    echo "Usage: $0 [on|mixed|off]"
    echo "  on    = Onion peers only (most private, slower)"
    echo "  mixed = Onion + clearnet peers (more peers)"
    echo "  off   = Clearnet only (fastest)"
    exit 1
fi

if [ "$1" = "on" ]; then
    echo "Switching to Tor onion-only mode..."
    sed -i.bak \
        -e "s|^#*proxy=.*|proxy=${TOR_PROXY}|" \
        -e 's|^onion=.*|#onion='"${TOR_PROXY}"'|' \
        -e 's/^#*onlynet=onion/onlynet=onion/' \
        -e 's/^dnsseed=1/dnsseed=0/' \
        -e 's/^dns=1/dns=0/' \
        "$CONF"
    echo "Tor ON (onion only) — .onion peers only, no clearnet."

elif [ "$1" = "mixed" ]; then
    echo "Switching to Tor mixed mode..."
    if $VPN_ON; then
        # Clearnet through VPN, onion through Tor — two separate pipes
        sed -i.bak \
            -e "s|^#*proxy=.*|proxy=${VPN_PROXY}|" \
            -e "s|^#*onion=.*|onion=${TOR_PROXY}|" \
            -e 's/^onlynet=onion/#onlynet=onion/' \
            -e 's/^dnsseed=0/dnsseed=1/' \
            -e 's/^dns=0/dns=1/' \
            "$CONF"
        echo "Tor MIXED — clearnet via VPN, onion via Tor. Two independent pipes."
    else
        # All traffic through Tor
        sed -i.bak \
            -e "s|^#*proxy=.*|proxy=${TOR_PROXY}|" \
            -e 's|^onion=.*|#onion='"${TOR_PROXY}"'|' \
            -e 's/^onlynet=onion/#onlynet=onion/' \
            -e 's/^dnsseed=0/dnsseed=1/' \
            -e 's/^dns=0/dns=1/' \
            "$CONF"
        echo "Tor MIXED — onion + clearnet peers, all routed through Tor."
    fi

else
    echo "Switching to clearnet mode..."
    if $VPN_ON; then
        sed -i.bak \
            -e "s|^#*proxy=.*|proxy=${VPN_PROXY}|" \
            -e 's|^onion=.*|#onion='"${TOR_PROXY}"'|' \
            -e 's/^onlynet=onion/#onlynet=onion/' \
            -e 's/^dnsseed=0/dnsseed=1/' \
            -e 's/^dns=0/dns=1/' \
            "$CONF"
        echo "Tor OFF — clearnet through VPN. IP hidden by VPN."
    else
        sed -i.bak \
            -e 's|^proxy=.*|#proxy='"${TOR_PROXY}"'|' \
            -e 's|^onion=.*|#onion='"${TOR_PROXY}"'|' \
            -e 's/^onlynet=onion/#onlynet=onion/' \
            -e 's/^dnsseed=0/dnsseed=1/' \
            -e 's/^dns=0/dns=1/' \
            "$CONF"
        echo "Tor OFF — direct clearnet. Your real IP is visible to peers."
    fi
fi

rm -f "${CONF}.bak"

echo "Restarting Bitcoin container..."
docker compose restart bitcoin
echo "Done."
