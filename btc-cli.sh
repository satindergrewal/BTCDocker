#!/bin/bash
# Wrapper for bitcoin-cli inside the container
# Usage: ./btc-cli.sh <command> [args...]
#
# Examples:
#   ./btc-cli.sh -getinfo
#   ./btc-cli.sh getblockchaininfo
#   ./btc-cli.sh -netinfo 4
#   watch ./btc-cli.sh -getinfo
#   watch -t ./btc-cli.sh -netinfo 4

cd "$(dirname "$0")"
docker compose exec -T bitcoin bitcoin-cli -datadir=/data/.bitcoin -conf=/etc/bitcoin/bitcoin.conf "$@"
