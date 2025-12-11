#!/bin/bash
# Human-readable workspace comparison tool
# Compares Terraform configurations and plans between workspaces

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/terraform"

cd "$TERRAFORM_DIR" || exit 1

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Function to print section headers
print_header() {
    echo ""
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${CYAN}$1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Function to print workspace info
print_workspace_info() {
    local ws=$1
    terraform workspace select "$ws" >/dev/null 2>&1
    
    local resource_count
    resource_count=$(terraform state list 2>/dev/null | wc -l)
    
    echo -e "${BOLD}Workspace: ${GREEN}$ws${NC}"
    echo -e "  Resources in state: ${YELLOW}$resource_count${NC}"
    
    # Get key outputs if available (suppress warnings)
    if terraform output -json 2>/dev/null >/dev/null; then
        local alb_url
        alb_url=$(terraform output -raw alb_https_url 2>/dev/null | head -1 || echo "N/A")
        local db_id
        db_id=$(terraform output -raw db_instance_id 2>/dev/null | head -1 || echo "N/A")
        local instance_count
        instance_count=$(terraform output -raw instance_count 2>/dev/null | head -1 || echo "0")
        
        # Filter out "N/A" if actual value was retrieved
        if [ "$alb_url" != "N/A" ] && [ -n "$alb_url" ]; then
            echo -e "  ALB URL: ${CYAN}$alb_url${NC}"
        fi
        if [ "$db_id" != "N/A" ] && [ -n "$db_id" ]; then
            echo -e "  DB Instance: ${CYAN}$db_id${NC}"
        fi
        if [ "$instance_count" != "0" ] && [ "$instance_count" != "N/A" ]; then
            echo -e "  Instance Count: ${CYAN}$instance_count${NC}"
        fi
    else
        echo -e "  ${YELLOW}No outputs available (workspace not deployed)${NC}"
    fi
    echo ""
}

# Function to extract key values from plan
extract_plan_summary() {
    local ws=$1
    terraform workspace select "$ws" >/dev/null 2>&1
    
    # Get plan output
    local plan_file="/tmp/terraform-plan-${ws}.txt"
    terraform plan -no-color -out=/dev/null 2>&1 | tee "$plan_file" >/dev/null || true
    
    # Extract summary
    local summary
    summary=$(grep -E "(Plan:|No changes|to add|to change|to destroy)" "$plan_file" | head -5 || echo "Plan not available")
    echo "$summary"
    
    # Extract resource counts
    local to_add
    to_add=$(grep -oE "[0-9]+ to add" "$plan_file" | head -1 | grep -oE "[0-9]+" || echo "0")
    local to_change
    to_change=$(grep -oE "[0-9]+ to change" "$plan_file" | head -1 | grep -oE "[0-9]+" || echo "0")
    local to_destroy
    to_destroy=$(grep -oE "[0-9]+ to destroy" "$plan_file" | head -1 | grep -oE "[0-9]+" || echo "0")
    
    echo "$to_add|$to_change|$to_destroy"
}

# Function to compare workspace configurations
compare_configurations() {
    local ws1=$1
    local ws2=$2
    
    print_header "📊 Configuration Comparison: $ws1 vs $ws2"
    
    # Compare key configuration values
    echo -e "${BOLD}Key Differences:${NC}"
    echo ""
    
    # Switch to each workspace and get configuration
    terraform workspace select "$ws1" >/dev/null 2>&1
    local ws1_config="/tmp/workspace-config-${ws1}.txt"
    terraform show -no-color 2>/dev/null | grep -E "(instance_type|min_size|max_size|desired_capacity|db_instance_type|deletion_protection)" | head -20 > "$ws1_config" || echo "" > "$ws1_config"
    
    terraform workspace select "$ws2" >/dev/null 2>&1
    local ws2_config="/tmp/workspace-config-${ws2}.txt"
    terraform show -no-color 2>/dev/null | grep -E "(instance_type|min_size|max_size|desired_capacity|db_instance_type|deletion_protection)" | head -20 > "$ws2_config" || echo "" > "$ws2_config"
    
    # Use diff with readable output
    if command -v diff &> /dev/null; then
        diff --side-by-side --width=120 --suppress-common-lines "$ws1_config" "$ws2_config" || true
    else
        diff -u "$ws1_config" "$ws2_config" || true
    fi
    
    echo ""
}

# Function to show resource comparison table
show_resource_comparison() {
    local ws1=$1
    local ws2=$2
    
    print_header "📋 Resource Comparison"
    
    # Get resource lists
    terraform workspace select "$ws1" >/dev/null 2>&1
    local ws1_resources="/tmp/workspace-resources-${ws1}.txt"
    terraform state list 2>/dev/null | sort > "$ws1_resources" || echo "" > "$ws1_resources"
    
    terraform workspace select "$ws2" >/dev/null 2>&1
    local ws2_resources="/tmp/workspace-resources-${ws2}.txt"
    terraform state list 2>/dev/null | sort > "$ws2_resources" || echo "" > "$ws2_resources"
    
    local ws1_count
    ws1_count=$(wc -l < "$ws1_resources")
    local ws2_count
    ws2_count=$(wc -l < "$ws2_resources")
    
    echo -e "${BOLD}Resource Counts:${NC}"
    echo -e "  ${CYAN}$ws1${NC}: ${YELLOW}$ws1_count${NC} resources"
    echo -e "  ${CYAN}$ws2${NC}: ${YELLOW}$ws2_count${NC} resources"
    echo ""
    
    # Show differences
    echo -e "${BOLD}Resources only in $ws1:${NC}"
    comm -23 "$ws1_resources" "$ws2_resources" | sed 's/^/  - /' | head -10 || echo "  (none)"
    echo ""
    
    echo -e "${BOLD}Resources only in $ws2:${NC}"
    comm -13 "$ws1_resources" "$ws2_resources" | sed 's/^/  - /' | head -10 || echo "  (none)"
    echo ""
    
    echo -e "${BOLD}Common resources:${NC}"
    local common_count
    common_count=$(comm -12 "$ws1_resources" "$ws2_resources" | wc -l)
    echo -e "  ${GREEN}$common_count${NC} resources exist in both workspaces"
    echo ""
}

# Function to show workspace-specific values
show_workspace_values() {
    local ws=$1
    
    print_header "⚙️  Workspace: $ws - Key Values"
    
    terraform workspace select "$ws" >/dev/null 2>&1
    
    # Try to extract values from workspaces.tf if it exists
    local workspaces_file="$TERRAFORM_DIR/workspaces.tf"
    if [ -f "$workspaces_file" ]; then
        # Extract workspace config from workspaces.tf
        local config_section
        config_section=$(grep -A 20 "workspace_config = {" "$workspaces_file" 2>/dev/null | grep -A 15 "^    $ws = {" 2>/dev/null || echo "")
        
        if [ -n "$config_section" ]; then
            echo -e "${BOLD}Expected Configuration (from workspaces.tf):${NC}"
            echo "$config_section" | grep -E "(instance_type|min_size|max_size|desired_capacity|db_instance_type|deletion_protection)" | sed 's/^      /  /' | sed 's/=//' | sed 's/"/ /g' || true
        else
            # Fallback: try to get from terraform plan or show
            echo -e "${BOLD}Configuration:${NC}"
            echo -e "  ${YELLOW}(Run 'terraform plan' to see actual configuration)${NC}"
        fi
    else
        # No workspaces.tf, show generic message
        echo -e "${BOLD}Configuration:${NC}"
        echo -e "  ${YELLOW}(Configuration managed in Terraform - check your workspace settings)${NC}"
    fi
    
    # Show known configurations for common workspace names (for reference)
    case "$ws" in
        dev|development)
            echo ""
            echo -e "${BOLD}Common Dev Configuration:${NC}"
            echo "  Instance Type: t3.micro"
            echo "  Min Size: 1"
            echo "  Max Size: 2"
            echo "  Desired Capacity: 1"
            echo "  DB Instance Type: db.t3.micro"
            echo "  Deletion Protection: ❌ Disabled"
            ;;
        staging|stage)
            echo ""
            echo -e "${BOLD}Common Staging Configuration:${NC}"
            echo "  Instance Type: t3.small"
            echo "  Min Size: 1"
            echo "  Max Size: 3"
            echo "  Desired Capacity: 2"
            echo "  DB Instance Type: db.t3.small"
            echo "  Deletion Protection: ❌ Disabled"
            ;;
        prod|production)
            echo ""
            echo -e "${BOLD}Common Prod Configuration:${NC}"
            echo "  Instance Type: t3.medium"
            echo "  Min Size: 2"
            echo "  Max Size: 5"
            echo "  Desired Capacity: 2"
            echo "  DB Instance Type: db.t3.medium"
            echo "  Deletion Protection: ✅ Enabled"
            ;;
    esac
    echo ""
}

# Function to create side-by-side comparison
side_by_side_comparison() {
    local ws1=$1
    local ws2=$2
    
    print_header "📊 Side-by-Side Comparison: $ws1 ↔ $ws2"
    
    printf "%-40s │ %s\n" "$ws1" "$ws2"
    printf "${CYAN}%-40s┼%s${NC}\n" "────────────────────────────────────────" "────────────────────────────────────────"
    
    # Compare outputs (suppress warnings)
    terraform workspace select "$ws1" >/dev/null 2>&1
    local ws1_url
    ws1_url=$(terraform output -raw alb_https_url 2>/dev/null | head -1 || echo "N/A")
    local ws1_db
    ws1_db=$(terraform output -raw db_instance_id 2>/dev/null | head -1 || echo "N/A")
    
    terraform workspace select "$ws2" >/dev/null 2>&1
    local ws2_url
    ws2_url=$(terraform output -raw alb_https_url 2>/dev/null | head -1 || echo "N/A")
    local ws2_db
    ws2_db=$(terraform output -raw db_instance_id 2>/dev/null | head -1 || echo "N/A")
    
    printf "%-40s │ %s\n" "ALB URL" "$ws1_url"
    printf "%-40s │ %s\n" "" "$ws2_url"
    printf "${CYAN}%-40s┼%s${NC}\n" "────────────────────────────────────────" "────────────────────────────────────────"
    
    printf "%-40s │ %s\n" "DB Instance" "$ws1_db"
    printf "%-40s │ %s\n" "" "$ws2_db"
    echo ""
}

# Main function
main() {
    echo -e "${BOLD}${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${MAGENTA}🔍 Terraform Workspace Comparison Tool${NC}"
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Get available workspaces
    local current_ws
    current_ws=$(terraform workspace show)
    # List all workspaces (removed hardcoded filter - works with any workspace name)
    local workspaces
    workspaces=$(terraform workspace list | grep -v "default" | awk '{print $1}' || echo "")
    
    echo -e "${BOLD}Current workspace: ${GREEN}$current_ws${NC}"
    echo ""
    
    # Parse arguments (works with any workspace names)
    local ws1="${1:-dev}"    # Default to 'dev' if not provided
    local ws2="${2:-staging}" # Default to 'staging' if not provided
    
    # Validate workspaces
    if ! terraform workspace list | grep -q "^[ *].*$ws1"; then
        echo -e "${RED}Error: Workspace '$ws1' does not exist${NC}"
        exit 1
    fi
    
    if ! terraform workspace list | grep -q "^[ *].*$ws2"; then
        echo -e "${RED}Error: Workspace '$ws2' does not exist${NC}"
        exit 1
    fi
    
    # Show workspace information
    print_header "📦 Workspace Overview"
    print_workspace_info "$ws1"
    print_workspace_info "$ws2"
    
    # Show workspace-specific configurations
    show_workspace_values "$ws1"
    show_workspace_values "$ws2"
    
    # Resource comparison
    show_resource_comparison "$ws1" "$ws2"
    
    # Side-by-side comparison
    side_by_side_comparison "$ws1" "$ws2"
    
    # Configuration comparison
    compare_configurations "$ws1" "$ws2"
    
    # Plan summaries
    print_header "📋 Plan Summaries"
    echo -e "${BOLD}$ws1 workspace plan:${NC}"
    extract_plan_summary "$ws1" | head -3
    echo ""
    
    echo -e "${BOLD}$ws2 workspace plan:${NC}"
    extract_plan_summary "$ws2" | head -3
    echo ""
    
    # Cleanup
    rm -f /tmp/terraform-plan-*.txt /tmp/workspace-*.txt 2>/dev/null || true
    
    print_header "✅ Comparison Complete"
    echo ""
    echo -e "${GREEN}Usage:${NC} $0 [workspace1] [workspace2]"
    echo -e "${GREEN}Example:${NC} $0 dev prod"
    echo ""
}

# Run main function
main "$@"

