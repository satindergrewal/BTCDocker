#!/bin/bash
# Toggle VPN (WireGuard) for the BTC Docker stack
# Usage: ./toggle-vpn.sh [on|off]
#
# SETUP: Place your WireGuard config at vpn/wg0.conf
#
# VPN on:  All traffic routes through WireGuard tunnel.
# VPN off: Direct internet.

set -euo pipefail
cd "$(dirname "$0")"

CONF="bitcoin.conf"
TOR_ON=false
grep -q "^proxy=" "$CONF" && grep -q "^onlynet=onion" "$CONF" && TOR_ON=true

if [ $# -ne 1 ] || [[ "$1" != "on" && "$1" != "off" ]]; then
    echo "Usage: $0 [on|off]"
    echo "  on  = Route all traffic through VPN"
    echo "  off = Direct internet (no VPN)"
    echo ""
    echo "Requires: vpn/wg0.conf (WireGuard config from your VPN provider)"
    exit 1
fi

if [ "$1" = "on" ]; then
    if [ ! -f vpn/wg0.conf ]; then
        echo "Error: vpn/wg0.conf not found."
        echo "Download your WireGuard config from your VPN provider and place it at vpn/wg0.conf"
        exit 1
    fi

    echo "Enabling VPN mode..."

    # Update proxy IP based on Tor state
    if $TOR_ON; then
        # Tor through VPN — SOCKS at VPN IP port 9050
        sed -i.bak 's/^proxy=.*/proxy=172.28.0.20:9050/' "$CONF"
    else
        # Clearnet through VPN — SOCKS proxy at VPN IP port 1080
        sed -i.bak 's/^#*proxy=.*/proxy=172.28.0.20:1080/' "$CONF"
    fi
    rm -f "${CONF}.bak"

    touch .vpn-mode

    docker compose -f docker-compose.yml -f docker-compose.vpn.yml down
    docker compose -f docker-compose.yml -f docker-compose.vpn.yml up -d

    echo "VPN ON — all traffic routed through WireGuard."

else
    echo "Disabling VPN mode..."

    # Update proxy based on Tor state
    if $TOR_ON; then
        # Tor without VPN — SOCKS at Tor IP port 9050
        sed -i.bak 's/^proxy=.*/proxy=172.28.0.10:9050/' "$CONF"
    else
        # No proxy at all
        sed -i.bak 's/^proxy=.*/#proxy=172.28.0.10:9050/' "$CONF"
    fi
    rm -f "${CONF}.bak"

    rm -f .vpn-mode

    docker compose -f docker-compose.yml -f docker-compose.vpn.yml down
    docker compose up -d

    echo "VPN OFF — direct internet."
fi

echo ""
echo "Done."
