# AWS Secrets Manager for RDS database credentials

# Secret for RDS database credentials
# This secret stores the connection information for the RDS PostgreSQL instance
resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "${local.name_prefix}-db-credentials"
  description = "RDS database credentials for ${local.name_prefix} application"

  # Set recovery window to 0 for immediate deletion on terraform destroy
  # Without this, secrets are scheduled for deletion with a 7-30 day recovery window
  # Setting to 0 ensures the secret is permanently deleted immediately
  recovery_window_in_days = var.force_delete_secret ? 0 : 7


  tags = {
    Name        = "${local.name_prefix}-db-credentials"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Initial secret version with placeholder credentials
# This will be automatically updated by the sync resource below
resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id

  # Initial placeholder - will be synced automatically from RDS-managed secret
  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password # Placeholder - will be updated automatically
    engine   = var.db_engine
    host     = module.database.db_instance_address
    port     = module.database.db_instance_port
    dbname   = var.db_name
  })

  depends_on = [
    module.database,
    aws_secretsmanager_secret.db_credentials
  ]

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# Automatic password sync from RDS-managed secret to custom secret
# This runs after database creation and whenever the RDS secret changes
# Works automatically for all workspaces (dev, staging, prod)
resource "null_resource" "sync_db_password" {
  # Trigger when database or RDS secret ARN changes
  triggers = {
    db_instance_id      = module.database.db_instance_identifier
    db_instance_address = module.database.db_instance_address
    rds_secret_arn      = try(module.database.db_instance_master_user_secret_arn, "")
    custom_secret_name  = aws_secretsmanager_secret.db_credentials.name
    region              = var.region
    workspace           = terraform.workspace
  }

  # Wait for database and secret to be ready before syncing
  depends_on = [
    module.database,
    aws_secretsmanager_secret_version.db_credentials,
    aws_secretsmanager_secret.db_credentials
  ]

  # Sync password using the backup script
  # This automatically reads from RDS-managed secret and updates our custom secret
  # Works automatically for all workspaces (dev, staging, prod)
  provisioner "local-exec" {
    command = <<-EOT
      # Change to infrastructure-web-app directory where sync script is located
      cd "${path.module}/.."
      
      # Run the sync script with auto mode and wait flag
      # The script automatically detects the current workspace and syncs the password
      bash sync-db-password.sh --auto --wait || {
        echo "Warning: Password sync script failed. This might be expected on first apply."
        echo "The password will be synced on the next apply, or you can run the script manually."
        exit 0  # Don't fail Terraform if sync fails (will retry on next apply)
      }
    EOT
  }
}

# IAM policy for EC2 instances to read secrets
resource "aws_iam_policy" "secrets_manager_read" {
  name        = "${local.name_prefix}-secrets-read-policy"
  description = "Policy to allow EC2 instances to read database credentials from Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          aws_secretsmanager_secret.db_credentials.arn,
          try(module.database.db_instance_master_user_secret_arn, "")
        ]
      }
    ]
  })

  tags = {
    Name = "${local.name_prefix}-secrets-read-policy"
  }
}

# Attach Secrets Manager policy to the EC2 role
resource "aws_iam_role_policy_attachment" "secrets_manager_read" {
  role       = aws_iam_role.app-server-role.name
  policy_arn = aws_iam_policy.secrets_manager_read.arn
}
