#!/bin/bash
# Script to sync database password - handles both managed and unmanaged passwords

set -e

# Check for flags
AUTO_MODE=false
WAIT_FOR_SECRET=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --auto)
            AUTO_MODE=true
            shift
            ;;
        --wait)
            WAIT_FOR_SECRET=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

REGION="us-east-1"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/terraform"

cd "$TERRAFORM_DIR" || exit 1

if [ "$AUTO_MODE" = false ]; then
    echo "=== Database Password Diagnostic ==="
    echo ""
fi

WORKSPACE=$(terraform workspace show 2>/dev/null || echo "default")
if [ "$AUTO_MODE" = false ]; then
    echo "Current Terraform workspace: $WORKSPACE"
    echo ""
fi

# Get RDS instance info - try to detect from Terraform output first
RDS_IDENTIFIER=$(terraform output -raw db_instance_id 2>/dev/null || echo "")
if [ -z "$RDS_IDENTIFIER" ]; then
    # Fallback to workspace-based naming
    RDS_IDENTIFIER="web-app-${WORKSPACE}-db-db"
fi

if [ "$AUTO_MODE" = false ]; then
    echo "Checking RDS instance: $RDS_IDENTIFIER"
fi

# Check if RDS instance exists
if ! aws rds describe-db-instances --db-instance-identifier "$RDS_IDENTIFIER" --region "$REGION" &>/dev/null; then
    if [ "$AUTO_MODE" = false ]; then
        echo "❌ RDS instance not found: $RDS_IDENTIFIER"
        echo "   Trying to find RDS instances with pattern 'web-app-*-db-db'..."
        # Try to find any matching RDS instance
        FOUND_INSTANCE=$(aws rds describe-db-instances --region "$REGION" --query "DBInstances[?contains(DBInstanceIdentifier, 'web-app-') && contains(DBInstanceIdentifier, '-db-db')].DBInstanceIdentifier" --output text | head -1)
        if [ -n "$FOUND_INSTANCE" ]; then
            echo "   Found: $FOUND_INSTANCE"
            RDS_IDENTIFIER="$FOUND_INSTANCE"
        else
            exit 1
        fi
    else
        exit 1
    fi
fi

# Get RDS details
RDS_INFO=$(aws rds describe-db-instances --db-instance-identifier "$RDS_IDENTIFIER" --region "$REGION" --query 'DBInstances[0]' --output json)
RDS_USERNAME=$(echo "$RDS_INFO" | python3 -c "import sys, json; print(json.load(sys.stdin)['MasterUsername'])")
RDS_MANAGE_PASSWORD=$(echo "$RDS_INFO" | python3 -c "import sys, json; print(json.load(sys.stdin).get('ManageMasterUserPassword', 'false'))")
RDS_SECRET_ARN=$(echo "$RDS_INFO" | python3 -c "import sys, json; secret = json.load(sys.stdin).get('MasterUserSecret', {}); print(secret.get('SecretArn', ''))")

if [ "$AUTO_MODE" = false ]; then
    echo "RDS Username: $RDS_USERNAME"
    echo "ManageMasterUserPassword: $RDS_MANAGE_PASSWORD"
    echo "RDS Managed Secret ARN: ${RDS_SECRET_ARN:-'None'}"
    echo ""
fi

# If RDS is managing password and we have --wait flag, wait for secret to be available
if [ "$WAIT_FOR_SECRET" = true ] && [ "$RDS_MANAGE_PASSWORD" = "True" ] && [ -n "$RDS_SECRET_ARN" ]; then
    if [ "$AUTO_MODE" = false ]; then
        echo "⏳ Waiting for RDS-managed secret to be available..."
    fi
    
    MAX_RETRIES=30
    RETRY_COUNT=0
    SECRET_READY=false
    
    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        if aws secretsmanager describe-secret --secret-id "$RDS_SECRET_ARN" --region "$REGION" &>/dev/null; then
            # Try to actually read the secret value
            if aws secretsmanager get-secret-value --secret-id "$RDS_SECRET_ARN" --region "$REGION" &>/dev/null 2>&1; then
                SECRET_READY=true
                break
            fi
        fi
        
        RETRY_COUNT=$((RETRY_COUNT + 1))
        if [ "$AUTO_MODE" = false ]; then
            echo "   Attempt $RETRY_COUNT/$MAX_RETRIES: Secret not ready yet, waiting 10 seconds..."
        fi
        sleep 10
    done
    
    if [ "$SECRET_READY" = false ]; then
        if [ "$AUTO_MODE" = false ]; then
            echo "⚠️  Warning: RDS-managed secret not available after $MAX_RETRIES attempts"
            echo "   This might be a timing issue. The sync will continue anyway."
        fi
    elif [ "$AUTO_MODE" = false ]; then
        echo "✅ RDS-managed secret is available"
        echo ""
    fi
fi

# Get our custom secret
SECRET_NAME="web-app-${WORKSPACE}-db-credential"
echo "Checking custom secret: $SECRET_NAME"

if ! aws secretsmanager describe-secret --secret-id "$SECRET_NAME" --region "$REGION" &>/dev/null; then
    echo "❌ Custom secret not found: $SECRET_NAME"
    exit 1
fi

SECRET_JSON=$(aws secretsmanager get-secret-value --secret-id "$SECRET_NAME" --region "$REGION" --query SecretString --output text)
SECRET_PASSWORD=$(echo "$SECRET_JSON" | python3 -c "import sys, json; print(json.load(sys.stdin)['password'])")
SECRET_USERNAME=$(echo "$SECRET_JSON" | python3 -c "import sys, json; print(json.load(sys.stdin)['username'])")

echo "Custom Secret Username: $SECRET_USERNAME"
echo "Custom Secret Password: ${SECRET_PASSWORD:0:4}****"
echo ""

# If RDS is managing the password, read from RDS secret
if [ "$RDS_MANAGE_PASSWORD" = "True" ] && [ -n "$RDS_SECRET_ARN" ]; then
    echo "📋 RDS is managing the password. Reading from RDS-managed secret..."
    RDS_SECRET_JSON=$(aws secretsmanager get-secret-value --secret-id "$RDS_SECRET_ARN" --region "$REGION" --query SecretString --output text)
    RDS_SECRET_PASSWORD=$(echo "$RDS_SECRET_JSON" | python3 -c "import sys, json; print(json.load(sys.stdin)['password'])")
    RDS_SECRET_USERNAME=$(echo "$RDS_SECRET_JSON" | python3 -c "import sys, json; print(json.load(sys.stdin)['username'])")
    
    echo "RDS Managed Secret Username: $RDS_SECRET_USERNAME"
    echo "RDS Managed Secret Password: ${RDS_SECRET_PASSWORD:0:4}****"
    echo ""
    
    # Update our custom secret to match RDS secret
    echo "🔄 Updating custom secret to match RDS-managed password..."
    SECRET_HOST=$(echo "$SECRET_JSON" | python3 -c "import sys, json; print(json.load(sys.stdin)['host'])")
    SECRET_PORT=$(echo "$SECRET_JSON" | python3 -c "import sys, json; print(json.load(sys.stdin)['port'])")
    SECRET_DBNAME=$(echo "$SECRET_JSON" | python3 -c "import sys, json; print(json.load(sys.stdin)['dbname'])")
    SECRET_ENGINE=$(echo "$SECRET_JSON" | python3 -c "import sys, json; print(json.load(sys.stdin)['engine'])")
    
    NEW_SECRET_JSON=$(python3 -c "
import json, sys
print(json.dumps({
    'username': '$RDS_SECRET_USERNAME',
    'password': '$RDS_SECRET_PASSWORD',
    'engine': '$SECRET_ENGINE',
    'host': '$SECRET_HOST',
    'port': int('$SECRET_PORT'),
    'dbname': '$SECRET_DBNAME'
}))
")
    
    aws secretsmanager update-secret \
        --secret-id "$SECRET_NAME" \
        --secret-string "$NEW_SECRET_JSON" \
        --region "$REGION"
    
    echo "✅ Custom secret updated to match RDS-managed password"
    echo ""
    echo "🎉 Password sync complete!"
    echo "   Your application should now be able to connect"
    
elif [ -n "$RDS_SECRET_ARN" ]; then
    # RDS has a secret ARN even though ManageMasterUserPassword might be false
    # This means the secret exists and we should read from it
    echo "📋 RDS has a managed secret (ARN found). Reading password from it..."
    RDS_SECRET_JSON=$(aws secretsmanager get-secret-value --secret-id "$RDS_SECRET_ARN" --region "$REGION" --query SecretString --output text)
    RDS_SECRET_PASSWORD=$(echo "$RDS_SECRET_JSON" | python3 -c "import sys, json; print(json.load(sys.stdin)['password'])")
    RDS_SECRET_USERNAME=$(echo "$RDS_SECRET_JSON" | python3 -c "import sys, json; print(json.load(sys.stdin)['username'])")
    
    echo "RDS Managed Secret Username: $RDS_SECRET_USERNAME"
    echo "RDS Managed Secret Password: ${RDS_SECRET_PASSWORD:0:4}****"
    echo ""
    
    # Update our custom secret to match RDS secret
    echo "🔄 Updating custom secret to match RDS-managed password..."
    SECRET_HOST=$(echo "$SECRET_JSON" | python3 -c "import sys, json; print(json.load(sys.stdin)['host'])")
    SECRET_PORT=$(echo "$SECRET_JSON" | python3 -c "import sys, json; print(json.load(sys.stdin)['port'])")
    SECRET_DBNAME=$(echo "$SECRET_JSON" | python3 -c "import sys, json; print(json.load(sys.stdin)['dbname'])")
    SECRET_ENGINE=$(echo "$SECRET_JSON" | python3 -c "import sys, json; print(json.load(sys.stdin)['engine'])")
    
    NEW_SECRET_JSON=$(python3 -c "
import json, sys
print(json.dumps({
    'username': '$RDS_SECRET_USERNAME',
    'password': '$RDS_SECRET_PASSWORD',
    'engine': '$SECRET_ENGINE',
    'host': '$SECRET_HOST',
    'port': int('$SECRET_PORT'),
    'dbname': '$SECRET_DBNAME'
}))
")
    
    aws secretsmanager update-secret \
        --secret-id "$SECRET_NAME" \
        --secret-string "$NEW_SECRET_JSON" \
        --region "$REGION"
    
    echo "✅ Custom secret updated to match RDS-managed password"
    echo ""
    echo "🎉 Password sync complete!"
    echo "   Your application should now be able to connect"
    
elif [ "$RDS_MANAGE_PASSWORD" = "False" ] || [ -z "$RDS_SECRET_ARN" ]; then
    echo "ℹ️  RDS is NOT managing the password (using manual password)"
    echo ""
    echo "The error suggests RDS might have ManageMasterUserPassword enabled,"
    echo "but the instance shows it's not. This might be a timing issue or"
    echo "the instance needs to be updated."
    echo ""
    echo "Let's try a different approach:"
    echo "  1. We'll update Terraform to properly read from RDS-managed secret"
    echo "  2. Or manually test the connection with the current password"
    echo ""
    echo "To test the connection, you can run:"
    echo "  psql -h $SECRET_HOST -U $SECRET_USERNAME -d $SECRET_DBNAME"
    echo ""
else
    echo "❓ Unable to determine password management status"
    echo "   Please check RDS console for more details"
fi

