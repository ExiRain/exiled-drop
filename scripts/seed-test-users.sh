#!/usr/bin/env bash
#
# seed-test-users.sh — Create test users for development
#
set -euo pipefail

API_PORT="${EXILED_API_PORT:-8080}"
API_URL="http://localhost:${API_PORT}/api"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo ""
echo "═══════════════════════════════════════════"
echo "  Exiled Drop — Seed Test Users"
echo "═══════════════════════════════════════════"
echo ""

# Check if API is running
if ! curl -s -o /dev/null -w "%{http_code}" "$API_URL/auth/login" -X POST -H "Content-Type: application/json" -d '{}' &>/dev/null; then
    echo -e "  ${RED}✗ API not reachable at $API_URL${NC}"
    echo "  Run ./scripts/start-backend.sh first."
    exit 1
fi

register_user() {
    local username="$1"
    local display_name="$2"
    local password="$3"

    echo "→ Registering $username..."

    local response
    local http_code
    response=$(curl -s -w "\n%{http_code}" -X POST "$API_URL/auth/register" \
        -H "Content-Type: application/json" \
        -d "{\"username\":\"$username\",\"displayName\":\"$display_name\",\"password\":\"$password\"}")

    http_code=$(echo "$response" | tail -1)
    local body=$(echo "$response" | head -n -1)

    if [ "$http_code" = "201" ]; then
        local access_token=$(echo "$body" | grep -o '"accessToken":"[^"]*"' | cut -d'"' -f4)
        echo -e "  ${GREEN}✓ $username registered${NC}"
        echo "    Access token: ${access_token:0:40}..."
        echo ""
    elif [ "$http_code" = "400" ]; then
        # Likely "username already taken" — try login instead
        echo -e "  ${YELLOW}○ $username already exists, logging in...${NC}"

        response=$(curl -s -w "\n%{http_code}" -X POST "$API_URL/auth/login" \
            -H "Content-Type: application/json" \
            -d "{\"username\":\"$username\",\"password\":\"$password\"}")

        http_code=$(echo "$response" | tail -1)
        body=$(echo "$response" | head -n -1)

        if [ "$http_code" = "200" ]; then
            local access_token=$(echo "$body" | grep -o '"accessToken":"[^"]*"' | cut -d'"' -f4)
            echo -e "  ${GREEN}✓ $username logged in${NC}"
            echo "    Access token: ${access_token:0:40}..."
            echo ""
        else
            echo -e "  ${RED}✗ Failed to login $username: $body${NC}"
            echo ""
        fi
    else
        echo -e "  ${RED}✗ Failed to register $username (HTTP $http_code): $body${NC}"
        echo ""
    fi
}

register_user "alice" "Alice" "password123"
register_user "bob" "Bob" "password123"

echo "───────────────────────────────────────────"
echo "  Test users ready! Use the tokens above"
echo "  to test API calls or WebSocket connections."
echo ""
echo "  Quick test (list conversations as alice):"
echo "  curl -H 'Authorization: Bearer <token>' $API_URL/conversations"
echo ""
