#!/bin/bash
# Simple and clean workspace diff tool
# Compares Terraform plans/outputs between two workspaces

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/terraform"

cd "$TERRAFORM_DIR" || exit 1

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# Function to get plan summary
get_plan_summary() {
    local ws=$1
    terraform workspace select "$ws" >/dev/null 2>&1
    
    echo "Generating plan for $ws..." >&2
    terraform plan -no-color -out=/dev/null 2>&1 | grep -E "Plan:|No changes" | head -1
}

# Function to get outputs
get_outputs() {
    local ws=$1
    terraform workspace select "$ws" >/dev/null 2>&1
    
    if terraform output -json >/dev/null 2>&1; then
        echo "Workspace: $ws"
        terraform output 2>/dev/null | grep -v "Outputs:" || echo "No outputs available"
    else
        echo "Workspace: $ws (no resources deployed yet)"
    fi
}

# Function to compare plans
compare_plans() {
    local ws1=$1
    local ws2=$2
    
    echo -e "${BOLD}${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}Comparing: ${GREEN}$ws1${NC} vs ${GREEN}$ws2${NC}${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Get plan summaries
    echo -e "${BOLD}Plan Summary:${NC}"
    echo -e "${YELLOW}$ws1:${NC} $(get_plan_summary "$ws1")"
    echo -e "${YELLOW}$ws2:${NC} $(get_plan_summary "$ws2")"
    echo ""
    
    # Get outputs comparison
    echo -e "${BOLD}Outputs Comparison:${NC}"
    echo ""
    echo -e "${CYAN}━━━ $ws1 ━━━${NC}"
    get_outputs "$ws1"
    echo ""
    echo -e "${CYAN}━━━ $ws2 ━━━${NC}"
    get_outputs "$ws2"
    echo ""
}

# Main
if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <workspace1> <workspace2>"
    echo "Example: $0 dev prod"
    exit 1
fi

compare_plans "$1" "$2"

