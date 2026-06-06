#!/bin/bash
# Manual update script for BTC Docker stack
# Usage: ./update.sh [bitcoin_version]
#
# Examples:
#   ./update.sh           # Rebuilds Tor and Bitcoin with current versions, pulls latest Fulcrum
#   ./update.sh 31.1      # Rebuilds Bitcoin with version 31.1

set -euo pipefail

COMPOSE_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$COMPOSE_DIR"

echo "=== BTC Docker Stack Updater ==="
echo ""

# Show current state
echo "Current containers:"
docker compose ps
echo ""

# If a Bitcoin version is provided, update the Dockerfile
if [ $# -ge 1 ]; then
    NEW_VERSION="$1"
    echo "Updating Bitcoin Core to version ${NEW_VERSION}..."
    sed -i.bak "s/^ARG BITCOIN_VERSION=.*/ARG BITCOIN_VERSION=${NEW_VERSION}/" bitcoin/Dockerfile
    rm -f bitcoin/Dockerfile.bak
    echo ""
fi

# Pull latest Fulcrum image (only container using a remote image)
echo "Pulling latest Fulcrum image..."
docker compose pull fulcrum
echo ""

# Rebuild local images (Tor + Bitcoin) and recreate all containers
echo "Rebuilding local images (Tor, Bitcoin) and recreating containers..."
echo "(Data is preserved — no blockchain re-download)"
echo ""
docker compose build --no-cache
docker compose up -d --remove-orphans
echo ""

# Show running status
echo "=== Stack Status ==="
docker compose ps
echo ""

# Show Bitcoin version
echo "Bitcoin Core version:"
docker compose exec bitcoin bitcoind --version | head -1
echo ""

echo "Update complete. Monitor logs with:"
echo "  docker compose -f \"$COMPOSE_DIR/docker-compose.yml\" logs -f"
