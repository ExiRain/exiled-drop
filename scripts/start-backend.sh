#!/usr/bin/env bash
#
# start-backend.sh — Build and run the Spring Boot backend
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo ""
echo "→ Starting Exiled Drop backend..."

cd "$PROJECT_ROOT/backend"

# Check if gradlew exists
if [ ! -f "gradlew" ]; then
    echo "  gradlew not found. Run ./scripts/init-project.sh first."
    exit 1
fi

# Build Spring profiles — always include local if the file exists
PROFILES=""
LOCAL_PROPS="src/main/resources/application-local.properties"
if [ -f "$LOCAL_PROPS" ]; then
    PROFILES="local"
    echo -e "  ${YELLOW}Using local profile${NC} (application-local.properties)"
fi

# Check if PostgreSQL is reachable
if ! docker exec exiled-postgres pg_isready -U exileddrop -q 2>/dev/null; then
    echo -e "  ${YELLOW}PostgreSQL doesn't seem to be running.${NC}"
    echo "  Run ./scripts/start-infra.sh first, or start it manually."
    echo ""
    read -p "  Continue anyway? (y/N) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "→ Building and starting..."
echo ""

if [ -n "$PROFILES" ]; then
    ./gradlew bootRun --args="--spring.profiles.active=$PROFILES" --no-daemon
else
    ./gradlew bootRun --no-daemon
fi
