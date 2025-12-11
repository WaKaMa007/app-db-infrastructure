#!/bin/bash
# Script to set up Terraform workspaces for dev, staging, and prod
# This helps you get started with the workspace workflow

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/terraform"

cd "$TERRAFORM_DIR" || exit 1

echo "🚀 Terraform Workspace Setup"
echo "============================"
echo ""

# Check if we're in the right directory
if [ ! -f "workspaces.tf" ]; then
    echo "❌ Error: workspaces.tf not found. Are you in the terraform directory?"
    exit 1
fi

# Show current workspace
CURRENT_WS=$(terraform workspace show 2>/dev/null || echo "unknown")
echo "Current workspace: $CURRENT_WS"
echo ""

# List existing workspaces
echo "Existing workspaces:"
terraform workspace list
echo ""

# Function to create workspace if it doesn't exist
create_workspace() {
    local ws_name=$1
    if terraform workspace list | grep -q "^\s*${ws_name}\s*$"; then
        echo "✅ Workspace '$ws_name' already exists"
    else
        echo "Creating workspace '$ws_name'..."
        terraform workspace new "$ws_name" || {
            echo "⚠️  Failed to create workspace '$ws_name'"
            return 1
        }
        echo "✅ Workspace '$ws_name' created"
    fi
}

# Create all workspaces
echo "Setting up workspaces..."
echo ""

create_workspace "dev"
create_workspace "staging"
create_workspace "prod"

echo ""
echo "✅ All workspaces created!"
echo ""

# Show workspace configurations
echo "📋 Workspace Configurations:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "| Environment | Instance | Min | Max | Desired | DB Type | Deletion Protection |"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "| dev         | t3.micro | 1   | 2   | 1       | db.t3.micro | ❌ Disabled    |"
echo "| staging     | t3.small | 1   | 3   | 2       | db.t3.small | ❌ Disabled    |"
echo "| prod        | t3.medium| 2   | 5   | 2       | db.t3.medium| ✅ Enabled     |"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Show current workspace
CURRENT_WS=$(terraform workspace show)
echo "Current workspace: $CURRENT_WS"
echo ""

# Provide next steps
echo "📝 Next Steps:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. Select a workspace:"
echo "   terraform workspace select dev"
echo "   terraform workspace select staging"
echo "   terraform workspace select prod"
echo ""
echo "2. Deploy infrastructure:"
echo "   terraform plan"
echo "   terraform apply"
echo ""
echo "3. Follow the promotion workflow:"
echo "   - Develop in DEV"
echo "   - Promote to STAGING"
echo "   - Promote to PROD"
echo "   - Commit to Git"
echo ""
echo "📖 Documentation:"
echo "   - WORKSPACE_SETUP.md - Complete workflow guide"
echo "   - PROMOTION_CHECKLIST.md - Step-by-step checklist"
echo "   - DEPLOYMENT_WORKFLOW.md - Deployment procedures"
echo ""

