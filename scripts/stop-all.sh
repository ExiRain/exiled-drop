#!/usr/bin/env bash
#
# stop-all.sh — Stop backend and all Docker containers
#
# Usage:
#   ./scripts/stop-all.sh           # stop containers, keep data
#   ./scripts/stop-all.sh --clean   # stop containers AND delete volumes
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPOSE_DIR="$PROJECT_ROOT/docker"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

CLEAN=false
if [[ "${1:-}" == "--clean" ]]; then
    CLEAN=true
fi

echo ""
echo "→ Stopping Exiled Drop..."

# Detect compose command
if docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
else
    COMPOSE_CMD="docker-compose"
fi

# Stop Docker containers
cd "$COMPOSE_DIR"
if [ "$CLEAN" = true ]; then
    echo -e "  ${YELLOW}Stopping containers and removing volumes...${NC}"
    $COMPOSE_CMD down -v
    echo -e "  ${GREEN}✓ Containers stopped, volumes removed${NC}"
else
    $COMPOSE_CMD down
    echo -e "  ${GREEN}✓ Containers stopped${NC} (data preserved)"
fi

echo ""
echo "  To restart: ./scripts/start-infra.sh && ./scripts/start-backend.sh"
if [ "$CLEAN" = true ]; then
    echo -e "  ${YELLOW}Note: database was wiped. Run ./scripts/seed-test-users.sh after restart.${NC}"
fi
echo ""
