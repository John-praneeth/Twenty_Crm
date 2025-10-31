#!/bin/bash

echo "════════════════════════════════════════════════════════════"
echo "  Twenty CRM - Railway Deployment Readiness Check"
echo "════════════════════════════════════════════════════════════"
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

check_pass() {
    echo -e "${GREEN}✓${NC} $1"
}

check_fail() {
    echo -e "${RED}✗${NC} $1"
}

check_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Track if all checks pass
ALL_PASS=true

echo "Checking repository structure..."
echo ""

# Check Dockerfile exists
if [ -f "packages/twenty-docker/twenty/Dockerfile" ]; then
    check_pass "Dockerfile found at packages/twenty-docker/twenty/Dockerfile"
else
    check_fail "Dockerfile NOT found at packages/twenty-docker/twenty/Dockerfile"
    ALL_PASS=false
fi

# Check entrypoint script exists
if [ -f "packages/twenty-docker/twenty/entrypoint.sh" ]; then
    check_pass "Entrypoint script found"
else
    check_fail "Entrypoint script NOT found"
    ALL_PASS=false
fi

# Check package.json exists
if [ -f "package.json" ]; then
    check_pass "Root package.json found"
else
    check_fail "Root package.json NOT found"
    ALL_PASS=false
fi

# Check server package.json
if [ -f "packages/twenty-server/package.json" ]; then
    check_pass "Server package.json found"

    # Check for required scripts
    if grep -q '"worker:prod"' packages/twenty-server/package.json; then
        check_pass "worker:prod script exists"
    else
        check_fail "worker:prod script NOT found in package.json"
        ALL_PASS=false
    fi

    if grep -q '"database:init:prod"' packages/twenty-server/package.json; then
        check_pass "database:init:prod script exists"
    else
        check_fail "database:init:prod script NOT found in package.json"
        ALL_PASS=false
    fi
else
    check_fail "Server package.json NOT found"
    ALL_PASS=false
fi

# Check yarn.lock exists
if [ -f "yarn.lock" ]; then
    check_pass "yarn.lock found (dependencies locked)"
else
    check_warn "yarn.lock NOT found (may cause dependency issues)"
fi

# Check railway.json
if [ -f "railway.json" ]; then
    check_pass "railway.json configuration found"

    # Verify Dockerfile path in railway.json
    if grep -q "packages/twenty-docker/twenty/Dockerfile" railway.json; then
        check_pass "Correct Dockerfile path in railway.json"
    else
        check_warn "Dockerfile path may be incorrect in railway.json"
    fi

    # Check health check configuration
    if grep -q '"/healthz"' railway.json; then
        check_pass "Health check configured in railway.json"
    else
        check_warn "Health check not found in railway.json"
    fi
else
    check_warn "railway.json NOT found (optional but recommended)"
fi

# Check if git repo
if [ -d ".git" ]; then
    check_pass "Git repository initialized"

    # Check if there are uncommitted changes
    if [ -n "$(git status --porcelain)" ]; then
        check_warn "You have uncommitted changes"
        echo "         Run 'git status' to see changes"
    else
        check_pass "No uncommitted changes"
    fi

    # Check remote
    if git remote get-url origin &> /dev/null; then
        REMOTE=$(git remote get-url origin)
        check_pass "Git remote configured: $REMOTE"
    else
        check_fail "No git remote configured"
        ALL_PASS=false
    fi
else
    check_fail "Not a git repository"
    ALL_PASS=false
fi

echo ""
echo "════════════════════════════════════════════════════════════"

if [ "$ALL_PASS" = true ]; then
    echo -e "${GREEN}✓ Repository is ready for Railway deployment!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Push your code to GitHub if not already done"
    echo "2. Follow RAILWAY_QUICK_CHANGES.txt to configure Railway"
    echo "3. Deploy and monitor logs"
else
    echo -e "${RED}✗ Repository has issues that need to be fixed${NC}"
    echo ""
    echo "Please fix the errors above before deploying to Railway"
fi

echo "════════════════════════════════════════════════════════════"
echo ""
echo "For detailed configuration guide, see:"
echo "  - SWITCH_TO_REPO_BUILD.md (complete guide)"
echo "  - RAILWAY_QUICK_CHANGES.txt (quick reference)"
echo "  - RAILWAY_CONFIGURATION_ANALYSIS.md (detailed analysis)"
echo ""
