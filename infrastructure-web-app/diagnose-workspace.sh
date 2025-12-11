#!/bin/bash
# Diagnostic script to check workspace states and understand apply behavior

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/terraform"

cd "$TERRAFORM_DIR" || exit 1

echo "🔍 Workspace Diagnostic Tool"
echo "============================"
echo ""

# Function to check workspace status
check_workspace() {
    local ws_name=$1
    echo "📋 Checking workspace: $ws_name"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    terraform workspace select "$ws_name" 2>/dev/null || {
        echo "❌ Workspace '$ws_name' does not exist"
        echo ""
        return 1
    }
    
    # Count resources in state
    local resource_count
    resource_count=$(terraform state list 2>/dev/null | wc -l)
    
    echo "📊 Resource Count: $resource_count resources in state"
    echo ""
    
    if [ "$resource_count" -eq 0 ]; then
        echo "⚠️  This workspace has NO resources in state"
        echo "   Running 'terraform apply' will CREATE all resources from scratch"
        echo ""
        echo "   Expected behavior:"
        echo "   - terraform plan: Shows ~47 resources to be added"
        echo "   - terraform apply: Creates all 47 resources in AWS"
        echo ""
    else
        echo "✅ This workspace has resources in state"
        echo "   Running 'terraform apply' will:"
        echo "   - Compare current state with configuration"
        echo "   - Update only resources that changed"
        echo ""
        
        # Show main resources
        echo "Main resources:"
        terraform state list 2>/dev/null | grep -E "(module\.(vpc|database)|aws_(autoscaling|lb))" | head -5
        echo ""
    fi
    
    # Check if initialized
    if [ -d ".terraform" ]; then
        echo "✅ Terraform initialized"
    else
        echo "⚠️  Terraform NOT initialized - run 'terraform init'"
    fi
    echo ""
}

# Check all workspaces
echo "Current workspace: $(terraform workspace show)"
echo ""

check_workspace "dev"
check_workspace "staging"
check_workspace "prod"

# Summary
echo "📝 Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

terraform workspace select staging
staging_count=$(terraform state list 2>/dev/null | wc -l)

terraform workspace select prod
prod_count=$(terraform state list 2>/dev/null | wc -l)

echo "Staging resources: $staging_count"
echo "Prod resources:    $prod_count"
echo ""

if [ "$staging_count" -eq 0 ] && [ "$prod_count" -gt 0 ]; then
    echo "🔍 Analysis:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Staging workspace is EMPTY (0 resources)"
    echo "Prod workspace has resources ($prod_count resources)"
    echo ""
    echo "When you run 'terraform apply':"
    echo ""
    echo "  📦 STAGING:"
    echo "     - Should CREATE all resources (~47 resources)"
    echo "     - Shows: 'Plan: 47 to add, 0 to change, 0 to destroy'"
    echo "     - After typing 'yes': Creates everything in AWS"
    echo ""
    echo "  📦 PROD:"
    echo "     - Should UPDATE existing resources"
    echo "     - Shows: 'Plan: 0 to add, X to change, 0 to destroy'"
    echo "     - After typing 'yes': Updates only changed resources"
    echo ""
    echo "⚠️  IMPORTANT: Make sure you're running 'terraform apply' (not 'terraform plan')"
    echo "   And typing 'yes' when prompted!"
    echo ""
fi

echo "💡 Next Steps:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "To deploy to staging:"
echo "  1. terraform workspace select staging"
echo "  2. terraform plan      # Review what will be created"
echo "  3. terraform apply     # Actually create resources (type 'yes')"
echo ""
echo "To update prod:"
echo "  1. terraform workspace select prod"
echo "  2. terraform plan      # Review what will change"
echo "  3. terraform apply     # Apply changes (type 'yes')"
echo ""

