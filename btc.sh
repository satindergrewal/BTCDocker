#!/bin/bash
# BTC Docker Stack — single command interface
# Usage: ./btc.sh <command>

set -euo pipefail
cd "$(dirname "$0")"

# Detect VPN mode and set compose command accordingly
if [ -f .vpn-mode ]; then
    DC="docker compose -f docker-compose.yml -f docker-compose.vpn.yml"
else
    DC="docker compose"
fi

case "${1:-help}" in
    # Bitcoin
    info)       ./btc-cli.sh -getinfo ;;
    net)        ./btc-cli.sh -netinfo 4 ;;
    peers)      ./btc-cli.sh getpeerinfo ;;
    block)      ./btc-cli.sh getblockchaininfo ;;
    log)        $DC logs -f bitcoin ;;
    debug)      tail -f ./data/btc/debug.log ;;
    cli)        shift; ./btc-cli.sh "$@" ;;

    # Fulcrum
    fulc)       ./fulcrum-admin.sh getinfo ;;
    fulclog)    $DC logs -f fulcrum ;;
    clients)    ./fulcrum-admin.sh clients ;;
    query)      shift; ./fulcrum-admin.sh query "$@" ;;
    stats)      echo "http://127.0.0.1:8080/stats" && open http://127.0.0.1:8080/stats 2>/dev/null || true ;;

    # Mempool Explorer
    explorer)   echo "http://127.0.0.1:8181" && open http://127.0.0.1:8181 2>/dev/null || true ;;
    mempoollog) $DC logs -f mempool-backend ;;

    # Tor
    torlog)     $DC logs -f tor ;;
    torstatus)  $DC logs tor 2>&1 | grep -i "bootstrapped" | tail -1 ;;

    # VPN
    vpnlog)     $DC logs -f vpn ;;
    vpn)        shift; ./toggle-vpn.sh "$@" ;;
    myip)
        echo "Checking exit IP from each container..."
        echo ""
        if [ -f .vpn-mode ]; then
            echo "VPN:"
            $DC exec -T vpn sh -c "wget -qO- https://ipinfo.io 2>/dev/null" || echo "  no internet"
            echo ""
        fi
        echo -n "Tor:     "
        if grep -q "^proxy=.*:9050\|^onion=" bitcoin.conf; then
            TOR_STATUS=$($DC logs tor 2>&1 | grep -i "bootstrapped" | tail -1)
            if echo "$TOR_STATUS" | grep -q "100%"; then
                PEERINFO=$(./btc-cli.sh getpeerinfo 2>/dev/null || echo "[]")
                ONION=$(echo "$PEERINFO" | grep -c '"network": "onion"' || true)
                TOTAL=$(echo "$PEERINFO" | grep -c '"addr"' || true)
                ONION=$((ONION + 0))
                TOTAL=$((TOTAL + 0))
                CLEARNET=$((TOTAL - ONION))
                if grep -q "^onlynet=onion" bitcoin.conf; then
                    echo "ON — onion only ($ONION peers)"
                else
                    echo "MIXED ($ONION onion + $CLEARNET clearnet peers)"
                fi
            else
                echo "$TOR_STATUS" | sed 's/.*Bootstrapped //' | sed 's/\s*$//'
            fi
        else
            echo "OFF"
        fi
        echo ""
        echo "Host:"
        curl -s https://ipinfo.io 2>/dev/null || echo "  check failed"
        echo ""
        ;;

    speedtest)
        if [ -f .vpn-mode ]; then
            echo "Running speedtest through VPN..."
            $DC exec -T vpn sh -c "which speedtest-cli >/dev/null 2>&1 || apk add --no-cache -q speedtest-cli >/dev/null 2>&1; speedtest-cli --simple"
        else
            echo "Running speedtest (no VPN)..."
            $DC exec -T tor sh -c "which speedtest-cli >/dev/null 2>&1 || apt-get update -qq && apt-get install -y -qq speedtest-cli >/dev/null 2>&1; speedtest-cli --simple"
        fi
        ;;

    # Stack
    up)         $DC up -d ;;
    down)       $DC down ;;
    nuke)       $DC down --rmi all ;;
    repair)
        echo "Stopping Bitcoin..."
        $DC stop bitcoin
        echo "Removing corrupted chainstate..."
        rm -rf ./data/btc/chainstate
        echo "Rebuilding chainstate from existing blocks (this takes a while)..."
        $DC run --rm bitcoin -datadir=/data/.bitcoin -conf=/etc/bitcoin/bitcoin.conf -reindex-chainstate
        echo "Repair complete. Run: ./btc.sh up"
        ;;
    status)     $DC ps ;;
    logs)       $DC logs -f ;;
    update)     shift; ./update.sh "$@" ;;
    tor)        shift; ./toggle-tor.sh "$@" ;;
    mode)
        echo -n "Tor: "
        if grep -q "^onlynet=onion" bitcoin.conf; then
            echo "ON (onion only)"
        elif grep -q "^onion=\|^proxy=.*:9050" bitcoin.conf; then
            if [ -f .vpn-mode ]; then
                echo "MIXED (clearnet via VPN, onion via Tor)"
            else
                echo "MIXED (onion + clearnet through Tor)"
            fi
        else
            echo "OFF"
        fi
        echo -n "VPN: "
        [ -f .vpn-mode ] && echo "ON" || echo "OFF"
        ;;

    help|*)
        echo "BTC Docker Stack"
        echo ""
        echo "Bitcoin:"
        echo "  info      Node info (sync progress, version, peers)"
        echo "  net       Network/peer overview"
        echo "  peers     Detailed peer info"
        echo "  block     Blockchain info"
        echo "  log       Tail Bitcoin logs"
        echo "  debug     Tail debug.log"
        echo "  cli <cmd> Run any bitcoin-cli command"
        echo ""
        echo "Fulcrum:"
        echo "  fulc      Fulcrum server info"
        echo "  fulclog   Tail Fulcrum logs"
        echo "  clients   Connected wallet clients"
        echo "  query <a> Query an address"
        echo "  stats     Open stats dashboard in browser"
        echo ""
        echo "Explorer:"
        echo "  explorer  Open Mempool block explorer in browser"
        echo "  mempoollog Tail Mempool backend logs"
        echo ""
        echo "Tor & VPN:"
        echo "  torstatus Tor bootstrap progress (0-100%)"
        echo "  torlog    Tail Tor logs"
        echo "  vpnlog    Tail VPN logs"
        echo "  tor <on|mixed|off>  Toggle Tor (on=onion only, mixed=both)"
        echo "  vpn <on|off>  Toggle VPN (requires vpn/wg0.conf)"
        echo "  myip      Check exit IP (verify VPN/Tor is working)"
        echo "  speedtest Run speedtest through VPN/network"
        echo "  mode      Show current Tor/VPN status"
        echo ""
        echo "Stack:"
        echo "  up        Start all containers"
        echo "  down      Stop all containers"
        echo "  nuke      Stop and remove all images"
        echo "  repair    Fix corrupted chainstate (after crash/power loss)"
        echo "  status    Container status"
        echo "  logs      Tail all logs"
        echo "  update    Update images (optional: version arg)"
        ;;
esac
