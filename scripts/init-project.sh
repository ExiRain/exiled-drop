#!/usr/bin/env bash
#
# init-project.sh — One-time project initialization
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo ""
echo "═══════════════════════════════════════════"
echo "  Exiled Drop — Project Initialization"
echo "═══════════════════════════════════════════"
echo ""

# ── Step 1: Generate Gradle wrapper ──
echo "→ Generating Gradle wrapper..."
cd "$PROJECT_ROOT/backend"

if [ -f "gradlew" ]; then
    echo -e "  ${YELLOW}gradlew already exists, regenerating...${NC}"
fi

# Use system gradle if available, otherwise download
if command -v gradle &> /dev/null; then
    gradle wrapper --gradle-version=8.13 --no-daemon
else
    echo "  System gradle not found, downloading wrapper directly..."
    GRADLE_VERSION="8.13"
    GRADLE_ZIP="/tmp/gradle-${GRADLE_VERSION}-bin.zip"
    GRADLE_DIR="/tmp/gradle-${GRADLE_VERSION}"

    if [ ! -f "$GRADLE_ZIP" ]; then
        curl -sL "https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip" -o "$GRADLE_ZIP"
    fi

    if [ ! -d "$GRADLE_DIR" ]; then
        unzip -qo "$GRADLE_ZIP" -d /tmp
    fi

    "$GRADLE_DIR/bin/gradle" wrapper --gradle-version=${GRADLE_VERSION} --no-daemon
    rm -rf "$GRADLE_DIR" "$GRADLE_ZIP"
fi

chmod +x gradlew
echo -e "  ${GREEN}✓ Gradle wrapper generated${NC}"

# ── Step 2: Create local properties file ──
echo ""
echo "→ Creating local configuration..."

LOCAL_PROPS="$PROJECT_ROOT/backend/src/main/resources/application-local.properties"
if [ ! -f "$LOCAL_PROPS" ]; then
    cat > "$LOCAL_PROPS" << 'EOF'
# ── Local development overrides ──
# This file is gitignored. Put your machine-specific config here.

# Uncomment and change if your PostgreSQL runs on a different host/port:
# spring.datasource.url=jdbc:postgresql://localhost:5432/exileddrop
# spring.datasource.password=exileddrop_secret

# Change the JWT secret for production:
# app.jwt.secret=your-production-secret-at-least-64-chars

# TURN server config (change if coturn runs elsewhere):
# app.turn.url=turn:localhost:3478
# app.turn.username=exileddrop
# app.turn.credential=turnpassword
EOF
    echo -e "  ${GREEN}✓ Created application-local.properties${NC}"
else
    echo -e "  ${YELLOW}application-local.properties already exists, skipping${NC}"
fi

# ── Step 3: Add local properties to gitignore if not already there ──
GITIGNORE="$PROJECT_ROOT/.gitignore"
if ! grep -q "application-local.properties" "$GITIGNORE" 2>/dev/null; then
    echo "" >> "$GITIGNORE"
    echo "# Local dev config" >> "$GITIGNORE"
    echo "application-local.properties" >> "$GITIGNORE"
    echo -e "  ${GREEN}✓ Added application-local.properties to .gitignore${NC}"
fi

# ── Step 4: Test compilation ──
echo ""
echo "→ Running test compilation..."
cd "$PROJECT_ROOT/backend"

if ./gradlew compileJava --no-daemon 2>&1; then
    echo -e "  ${GREEN}✓ Compilation successful${NC}"
else
    echo -e "  ${RED}✗ Compilation failed — check errors above${NC}"
    exit 1
fi

echo ""
echo "───────────────────────────────────────────"
echo -e "  ${GREEN}Project initialized!${NC}"
echo "  Next: ./scripts/start-infra.sh"
echo ""
