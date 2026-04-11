#!/usr/bin/env bash
#
# check-prereqs.sh — Verify all required tools are installed
#
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

check() {
    local name="$1"
    local cmd="$2"
    local min_version="$3"
    local required="${4:-true}"

    if ! command -v "$cmd" &> /dev/null; then
        if [ "$required" = "true" ]; then
            echo -e "  ${RED}✗ $name — not found${NC}"
            ((FAIL++))
        else
            echo -e "  ${YELLOW}○ $name — not found (optional)${NC}"
            ((WARN++))
        fi
        return
    fi

    local version
    version=$("$cmd" --version 2>&1 | head -1 || true)
    echo -e "  ${GREEN}✓ $name${NC} — $version"
    ((PASS++))
}

check_java() {
    if ! command -v java &> /dev/null; then
        echo -e "  ${RED}✗ Java 21+ — not found${NC}"
        ((FAIL++))
        return
    fi

    local version
    version=$(java -version 2>&1 | head -1)
    local major
    major=$(java -version 2>&1 | head -1 | sed -E 's/.*"([0-9]+)\..*/\1/')

    if [ "$major" -ge 21 ] 2>/dev/null; then
        echo -e "  ${GREEN}✓ Java 21+${NC} — $version"
        ((PASS++))
    else
        echo -e "  ${RED}✗ Java 21+ — found $version (need 21 or higher)${NC}"
        echo -e "    ${YELLOW}Tip: install via SDKMAN: sdk install java 21.0.6-tem${NC}"
        ((FAIL++))
    fi

    if [ -n "${JAVA_HOME:-}" ]; then
        echo -e "    JAVA_HOME=$JAVA_HOME"
    else
        echo -e "    ${YELLOW}JAVA_HOME not set — some tools may use wrong JDK${NC}"
    fi
}

check_docker_compose() {
    # Docker Compose v2 (docker compose) or v1 (docker-compose)
    if docker compose version &> /dev/null; then
        local version
        version=$(docker compose version 2>&1 | head -1)
        echo -e "  ${GREEN}✓ Docker Compose${NC} — $version"
        ((PASS++))
    elif command -v docker-compose &> /dev/null; then
        local version
        version=$(docker-compose --version 2>&1 | head -1)
        echo -e "  ${GREEN}✓ Docker Compose (v1)${NC} — $version"
        echo -e "    ${YELLOW}Consider upgrading to Docker Compose v2${NC}"
        ((PASS++))
    else
        echo -e "  ${RED}✗ Docker Compose — not found${NC}"
        ((FAIL++))
    fi
}

echo ""
echo "═══════════════════════════════════════════"
echo "  Exiled Drop — Prerequisites Check"
echo "═══════════════════════════════════════════"
echo ""
echo "Required:"
check_java
check "Docker" "docker" "20"
check_docker_compose

echo ""
echo "Optional (needed later):"
check "Flutter" "flutter" "3" "false"
check "Git" "git" "2" "false"

echo ""
echo "───────────────────────────────────────────"
if [ $FAIL -eq 0 ]; then
    echo -e "  ${GREEN}All required tools found!${NC} ($PASS passed, $WARN optional missing)"
    echo "  You're ready to run: ./scripts/init-project.sh"
else
    echo -e "  ${RED}$FAIL required tool(s) missing.${NC} Fix the issues above before proceeding."
    exit 1
fi
echo ""
