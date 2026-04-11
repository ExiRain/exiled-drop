#!/usr/bin/env bash
#
# start-infra.sh — Start PostgreSQL and coturn via Docker Compose
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPOSE_DIR="$PROJECT_ROOT/docker"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo ""
echo "→ Starting infrastructure (PostgreSQL + coturn)..."

# Detect compose command
if docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
else
    COMPOSE_CMD="docker-compose"
fi

cd "$COMPOSE_DIR"

# Start only infrastructure services (not the API — we run that locally for dev)
$COMPOSE_CMD up -d postgres coturn

# Wait for PostgreSQL to be ready
echo "→ Waiting for PostgreSQL to be healthy..."
RETRIES=30
until docker exec exiled-postgres pg_isready -U exileddrop -q 2>/dev/null; do
    ((RETRIES--))
    if [ $RETRIES -le 0 ]; then
        echo "  ✗ PostgreSQL failed to start. Check: docker logs exiled-postgres"
        exit 1
    fi
    sleep 1
done

echo -e "  ${GREEN}✓ PostgreSQL is ready${NC} (localhost:5432)"
echo -e "  ${GREEN}✓ coturn is ready${NC} (localhost:3478)"
echo ""
echo "  Database: exileddrop"
echo "  User:     exileddrop"
echo "  Password: exileddrop_secret"
echo ""
echo "  Next: ./scripts/start-backend.sh"
echo ""
