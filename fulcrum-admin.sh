#!/bin/bash
# Wrapper for Fulcrum admin RPC commands
# Usage: ./fulcrum-admin.sh <command> [args...]
#
# Examples:
#   ./fulcrum-admin.sh getinfo
#   ./fulcrum-admin.sh clients
#   ./fulcrum-admin.sh peers
#   ./fulcrum-admin.sh query <address>
#   watch ./fulcrum-admin.sh getinfo

cd "$(dirname "$0")"
docker compose exec -T fulcrum FulcrumAdmin -p 8000 "$@"
