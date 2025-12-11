#!/bin/bash
# Script to fix RDS password mismatch between Secrets Manager and RDS instance
# This script will update the RDS master password to match the one in Secrets Manager

set -e

REGION="us-east-1"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/terraform"

cd "$TERRAFORM_DIR" || exit 1

echo "=== RDS Password Sync Diagnostic and Fix ==="
echo ""

# Check if we're in a Terraform workspace
WORKSPACE=$(terraform workspace show 2>/dev/null || echo "default")
echo "Current Terraform workspace: $WORKSPACE"

# Get outputs from Terraform
echo "📋 Getting Terraform outputs..."
if ! terraform output -json > /dev/null 2>&1; then
    echo "⚠️  Terraform outputs not available. Using defaults..."
    SECRET_NAME="web-app-${WORKSPACE}-db-credential"
    RDS_IDENTIFIER="web-app-${WORKSPACE}-db-db"
else
    SECRET_NAME=$(terraform output -raw secret_name 2>/dev/null || echo "web-app-${WORKSPACE}-db-credential")
    RDS_IDENTIFIER=$(terraform output -raw db_instance_id 2>/dev/null || echo "web-app-${WORKSPACE}-db-db")
fi

echo "Secret name: $SECRET_NAME"
echo "RDS Instance: $RDS_IDENTIFIER"
echo ""

# Get current password from Secrets Manager
echo "📋 Reading password from Secrets Manager..."
SECRET_JSON=$(aws secretsmanager get-secret-value --secret-id "$SECRET_NAME" --region "$REGION" --query SecretString --output text 2>/dev/null || echo "")

if [ -z "$SECRET_JSON" ]; then
    echo "❌ Could not read secret from Secrets Manager"
    echo "   Secret name: $SECRET_NAME"
    echo "   Please verify the secret exists and you have permissions"
    exit 1
fi

SECRET_PASSWORD=$(echo "$SECRET_JSON" | python3 -c "import sys, json; print(json.load(sys.stdin)['password'])" 2>/dev/null || echo "")
SECRET_USERNAME=$(echo "$SECRET_JSON" | python3 -c "import sys, json; print(json.load(sys.stdin)['username'])" 2>/dev/null || echo "")
SECRET_HOST=$(echo "$SECRET_JSON" | python3 -c "import sys, json; print(json.load(sys.stdin)['host'])" 2>/dev/null || echo "")

if [ -z "$SECRET_PASSWORD" ]; then
    echo "❌ Could not parse password from secret"
    exit 1
fi

echo "✅ Found secret:"
echo "   Username: $SECRET_USERNAME"
echo "   Host: $SECRET_HOST"
echo "   Password length: ${#SECRET_PASSWORD} characters"
echo ""

echo "🔧 Resetting RDS master password to match Secrets Manager..."
echo "   This will update the RDS master password to: ${SECRET_PASSWORD:0:4}****"
echo ""
read -p "Continue? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Cancelled."
    exit 0
fi

echo ""
echo "⚠️  Resetting RDS master password..."
aws rds modify-db-instance \
    --db-instance-identifier "$RDS_IDENTIFIER" \
    --master-user-password "$SECRET_PASSWORD" \
    --apply-immediately \
    --region "$REGION"

echo ""
echo "✅ RDS password reset initiated"
echo "   Note: This change is applied immediately and may cause brief connection interruptions"
echo "   The password change takes 2-5 minutes to complete"
echo ""
echo "⏳ Waiting for RDS modification to complete..."
aws rds wait db-instance-available --db-instance-identifier "$RDS_IDENTIFIER" --region "$REGION"
echo ""
echo "✅ RDS instance is available"
echo ""
echo "🎉 Password sync complete!"
echo "   The RDS password now matches the one in Secrets Manager"
echo "   Your application should now be able to connect"
echo ""
echo "💡 Tip: You may need to restart your application instances for the change to take effect"

