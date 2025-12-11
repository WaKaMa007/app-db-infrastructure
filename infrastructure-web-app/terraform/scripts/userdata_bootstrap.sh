#!/bin/bash
# Bootstrap script - downloads and executes the full userdata script from S3
# This script must remain under 16KB to fit in EC2 user_data

# Don't use 'set -e' - we want to continue and log errors instead of exiting
# Log everything for debugging
exec > >(tee -a /var/log/bootstrap.log|logger -t bootstrap -s 2>/dev/console) 2>&1

# Configuration - these will be injected by Terraform template
S3_KEY="scripts/userdata_client_app.sh"

echo "=== Bootstrap Script Starting ==="
echo "Timestamp: $(date)"
echo "S3 Bucket: ${s3_bucket_name}"
echo "S3 Key: $${S3_KEY}"
echo "Region: ${region}"

# Install AWS CLI if not present
if ! command -v aws &> /dev/null; then
    echo "Installing AWS CLI..."
    
    # Try snap first (doesn't require apt repositories, works even with network issues)
    if command -v snap &> /dev/null; then
        echo "Trying to install AWS CLI via snap..."
        if sudo snap install aws-cli --classic 2>/dev/null; then
            echo "✅ AWS CLI installed via snap"
            # Ensure snap bin is in PATH
            export PATH="/snap/bin:$PATH"
        else
            echo "⚠️  Snap install failed, trying apt..."
        fi
    fi
    
    # Fallback to apt if snap didn't work
    if ! command -v aws &> /dev/null; then
        echo "Trying to install AWS CLI via apt..."
        # Try apt update, but don't fail if it fails (network issues)
        sudo apt-get update -y 2>&1 | grep -v "Network is unreachable" || true
        
        # Try installing awscli, but continue if it fails
        if sudo apt-get install -y awscli 2>&1 | grep -v "Network is unreachable"; then
            echo "✅ AWS CLI installed via apt"
        else
            echo "⚠️  Apt install may have failed, checking if AWS CLI is available..."
        fi
    fi
    
    # Final fallback: Official AWS installer
    if ! command -v aws &> /dev/null; then
        echo "Trying official AWS CLI installer..."
        curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip" || {
            echo "⚠️  Failed to download AWS CLI installer"
        }
        
        if [ -f "/tmp/awscliv2.zip" ]; then
            if command -v unzip &> /dev/null || sudo apt-get install -y unzip 2>&1 | grep -v "Network is unreachable"; then
                unzip -q /tmp/awscliv2.zip -d /tmp 2>/dev/null && \
                sudo /tmp/aws/install 2>/dev/null && \
                rm -rf /tmp/aws /tmp/awscliv2.zip && \
                echo "✅ AWS CLI installed via official installer"
            fi
        fi
    fi
    
    # Wait for AWS CLI to be available and verify installation
    echo "Verifying AWS CLI installation..."
    RETRY_COUNT=0
    MAX_RETRIES=5
    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        # Check multiple possible locations
        if command -v aws &> /dev/null || [ -f /usr/local/bin/aws ] || [ -f /snap/bin/aws ]; then
            # Set PATH to include common locations
            export PATH="/usr/local/bin:/snap/bin:$PATH"
            if aws --version 2>/dev/null; then
                echo "✅ AWS CLI is ready"
                aws --version
                break
            fi
        fi
        RETRY_COUNT=$((RETRY_COUNT + 1))
        echo "Waiting for AWS CLI... (attempt $RETRY_COUNT/$MAX_RETRIES)"
        sleep 2
    done
    
    if ! command -v aws &> /dev/null && [ ! -f /usr/local/bin/aws ] && [ ! -f /snap/bin/aws ]; then
        echo "❌ CRITICAL: AWS CLI installation failed after all attempts"
        echo "Cannot proceed without AWS CLI to download userdata script from S3"
        echo "Bootstrap script will exit"
        exit 1
    fi
else
    echo "✅ AWS CLI already installed"
    aws --version
fi

# Configure AWS CLI region
export AWS_DEFAULT_REGION="${region}"
echo "AWS CLI region configured: ${region}"

# Download userdata script from S3
echo "Downloading userdata script from S3..."
USERDATA_SCRIPT="/tmp/userdata_client_app.sh"

# Retry logic for S3 download
MAX_RETRIES=10
RETRY_DELAY=10
DOWNLOAD_SUCCESS=false

echo "Attempting to download userdata script from S3..."
for i in $(seq 1 $MAX_RETRIES); do
    echo "Download attempt $i of $MAX_RETRIES..."
    if aws s3 cp "s3://${s3_bucket_name}/$${S3_KEY}" "$USERDATA_SCRIPT" --region "${region}" 2>&1; then
        echo "✅ Successfully downloaded userdata script"
        DOWNLOAD_SUCCESS=true
        break
    else
        ERROR_CODE=$?
        echo "⚠️  Download attempt $i failed (exit code: $ERROR_CODE)"
        if [ $i -lt $MAX_RETRIES ]; then
            echo "   Retrying in $RETRY_DELAY seconds..."
            sleep $RETRY_DELAY
        fi
    fi
done

# Verify script was downloaded
if [ "$DOWNLOAD_SUCCESS" = false ] || [ ! -f "$USERDATA_SCRIPT" ]; then
    echo "❌ CRITICAL: Failed to download userdata script after $MAX_RETRIES attempts"
    echo "   S3 Bucket: ${s3_bucket_name}"
    echo "   S3 Key: $${S3_KEY}"
    echo "   Region: ${region}"
    echo "   File path: $USERDATA_SCRIPT"
    echo ""
    echo "Checking AWS CLI availability..."
    which aws || echo "AWS CLI not found"
    echo ""
    echo "Checking S3 access..."
    aws s3 ls "s3://${s3_bucket_name}/" --region "${region}" || echo "Cannot list S3 bucket"
    echo ""
    echo "Bootstrap script will exit. Check logs above for details."
    exit 1
fi

# Make script executable
echo "Making script executable..."
chmod +x "$USERDATA_SCRIPT" || {
    echo "⚠️  Failed to make script executable, trying anyway..."
}

# Execute the downloaded script
echo "Executing userdata script..."
echo "Timestamp before execution: $(date)"

# Execute script and capture exit code
if bash "$USERDATA_SCRIPT"; then
    EXIT_CODE=$?
    echo "✅ Userdata script completed (exit code: $EXIT_CODE)"
else
    EXIT_CODE=$?
    echo "⚠️  Userdata script exited with code: $EXIT_CODE"
    echo "Check /var/log/user-data.log for details"
fi

echo "=== Bootstrap Script Completed ==="
echo "Timestamp: $(date)"
echo "Final exit code: $EXIT_CODE"
