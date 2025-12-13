#!/bin/bash
# Script to sync RDS-managed password to our custom Secrets Manager secret
# This fixes password authentication failures when RDS manages the password

set -e

WORKSPACE="${1:-dev}"
REGION="${2:-us-east-1}"

echo "🔧 Syncing database password from RDS-managed secret to custom secret"
echo "   Workspace: $WORKSPACE"
echo "   Region: $REGION"
echo ""

# Get the RDS instance identifier from Terraform output
cd "$(dirname "$0")"
export AWS_DEFAULT_REGION="$REGION"

echo "📋 Getting RDS instance information..."
DB_INSTANCE_ID=$(terraform -chdir=. workspace select "$WORKSPACE" >/dev/null 2>&1 && terraform -chdir=. output -raw db_instance_id 2>/dev/null || echo "")

if [ -z "$DB_INSTANCE_ID" ]; then
  echo "❌ Error: Could not get DB instance ID from Terraform output"
  echo "   Make sure you're in the terraform directory and have run terraform apply"
  exit 1
fi

echo "   RDS Instance: $DB_INSTANCE_ID"

# Get the RDS-managed secret ARN
echo "🔍 Getting RDS-managed secret ARN..."
RDS_SECRET_ARN=$(aws rds describe-db-instances \
  --db-instance-identifier "$DB_INSTANCE_ID" \
  --region "$REGION" \
  --query 'DBInstances[0].MasterUserSecret.SecretArn' \
  --output text 2>/dev/null || echo "")

if [ -z "$RDS_SECRET_ARN" ] || [ "$RDS_SECRET_ARN" == "None" ]; then
  echo "❌ Error: Could not get RDS-managed secret ARN"
  echo "   Make sure manage_master_user_password is enabled"
  exit 1
fi

echo "   RDS Secret ARN: $RDS_SECRET_ARN"

# Get our custom secret name from Terraform output
CUSTOM_SECRET_NAME=$(terraform -chdir=. output -raw secret_name 2>/dev/null || echo "")
if [ -z "$CUSTOM_SECRET_NAME" ]; then
  echo "❌ Error: Could not get custom secret name from Terraform output"
  exit 1
fi

echo "   Custom Secret: $CUSTOM_SECRET_NAME"

# Read the password from RDS-managed secret
echo "🔑 Reading password from RDS-managed secret..."
RDS_SECRET=$(aws secretsmanager get-secret-value \
  --secret-id "$RDS_SECRET_ARN" \
  --region "$REGION" \
  --query 'SecretString' \
  --output text)

RDS_USERNAME=$(echo "$RDS_SECRET" | python3 -c "import sys, json; print(json.load(sys.stdin)['username'])" 2>/dev/null)
RDS_PASSWORD=$(echo "$RDS_SECRET" | python3 -c "import sys, json; print(json.load(sys.stdin)['password'])" 2>/dev/null)

if [ -z "$RDS_PASSWORD" ]; then
  echo "❌ Error: Could not extract password from RDS secret"
  exit 1
fi

echo "   Username: $RDS_USERNAME"
echo "   Password: [REDACTED]"

# Get database connection info from current custom secret (to preserve host/port/dbname)
echo "📥 Reading current custom secret for connection info..."
CURRENT_SECRET=$(aws secretsmanager get-secret-value \
  --secret-id "$CUSTOM_SECRET_NAME" \
  --region "$REGION" \
  --query 'SecretString' \
  --output text 2>/dev/null || echo "{}")

DB_HOST=$(echo "$CURRENT_SECRET" | python3 -c "import sys, json; print(json.load(sys.stdin).get('host', ''))" 2>/dev/null || echo "")
DB_PORT=$(echo "$CURRENT_SECRET" | python3 -c "import sys, json; print(json.load(sys.stdin).get('port', '5432'))" 2>/dev/null || echo "5432")
DB_NAME=$(echo "$CURRENT_SECRET" | python3 -c "import sys, json; print(json.load(sys.stdin).get('dbname', ''))" 2>/dev/null || echo "")
DB_ENGINE=$(echo "$CURRENT_SECRET" | python3 -c "import sys, json; print(json.load(sys.stdin).get('engine', 'postgres'))" 2>/dev/null || echo "postgres")

# If we couldn't get these from current secret, get from RDS
if [ -z "$DB_HOST" ]; then
  DB_HOST=$(aws rds describe-db-instances \
    --db-instance-identifier "$DB_INSTANCE_ID" \
    --region "$REGION" \
    --query 'DBInstances[0].Endpoint.Address' \
    --output text)
fi

if [ -z "$DB_PORT" ]; then
  DB_PORT=$(aws rds describe-db-instances \
    --db-instance-identifier "$DB_INSTANCE_ID" \
    --region "$REGION" \
    --query 'DBInstances[0].Endpoint.Port' \
    --output text || echo "5432")
fi

if [ -z "$DB_NAME" ]; then
  DB_NAME=$(aws rds describe-db-instances \
    --db-instance-identifier "$DB_INSTANCE_ID" \
    --region "$REGION" \
    --query 'DBInstances[0].DBName' \
    --output text || echo "appdb")
fi

# Create updated secret JSON
echo "💾 Updating custom secret with RDS-managed password..."
UPDATED_SECRET=$(python3 <<EOF
import json
secret = {
    "username": "$RDS_USERNAME",
    "password": "$RDS_PASSWORD",
    "engine": "$DB_ENGINE",
    "host": "$DB_HOST",
    "port": int("$DB_PORT"),
    "dbname": "$DB_NAME"
}
print(json.dumps(secret))
EOF
)

# Update the custom secret
aws secretsmanager update-secret \
  --secret-id "$CUSTOM_SECRET_NAME" \
  --secret-string "$UPDATED_SECRET" \
  --region "$REGION" > /dev/null

echo "✅ Successfully updated custom secret with RDS-managed password"
echo ""
echo "📝 Summary:"
echo "   RDS Instance: $DB_INSTANCE_ID"
echo "   Database Host: $DB_HOST:$DB_PORT"
echo "   Database Name: $DB_NAME"
echo "   Username: $RDS_USERNAME"
echo "   Custom Secret: $CUSTOM_SECRET_NAME"
echo ""
echo "✨ The application should now be able to connect to the database"
echo "   (You may need to restart EC2 instances to pick up the new secret)"

