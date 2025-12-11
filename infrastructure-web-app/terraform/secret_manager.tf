# AWS Secrets Manager for RDS database credentials

# Secret for RDS database credentials
# This secret stores the connection information for the RDS PostgreSQL instance
resource "aws_secretsmanager_secret" "db_credential" {
  name        = "${local.name_prefix}-db-credential"
  description = "RDS database credentials for ${local.name_prefix} application"

  # Set recovery window to 0 for immediate deletion on terraform destroy
  # Without this, secrets are scheduled for deletion with a 7-30 day recovery window
  # Setting to 0 ensures the secret is permanently deleted immediately
  recovery_window_in_days = 0

  tags = {
    Name        = "${local.name_prefix}-db-credential"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Data source to read RDS-managed secret (when manage_master_user_password is true)
# This reads the password directly from AWS Secrets Manager during Terraform apply
# This is more reliable than external scripts and works automatically for all workspaces
# The count ensures we only try to read if the secret ARN exists
data "aws_secretsmanager_secret_version" "rds_managed_secret" {
  count = length(try(module.database.db_instance_master_user_secret_arn, "")) > 0 ? 1 : 0
  
  secret_id = module.database.db_instance_master_user_secret_arn

  # Only read after database is created and secret is available
  depends_on = [
    module.database
  ]
}

# Local values to extract password from RDS-managed secret or fallback to var.db_password
locals {
  # If RDS is managing the password, use it; otherwise use var.db_password
  # This works automatically during database creation for all workspaces
  db_password = length(data.aws_secretsmanager_secret_version.rds_managed_secret) > 0 ? (
    jsondecode(data.aws_secretsmanager_secret_version.rds_managed_secret[0].secret_string)["password"]
  ) : var.db_password
  
  # Username from RDS-managed secret or var.db_username
  db_username = length(data.aws_secretsmanager_secret_version.rds_managed_secret) > 0 ? (
    jsondecode(data.aws_secretsmanager_secret_version.rds_managed_secret[0].secret_string)["username"]
  ) : var.db_username
}

# Secret version with actual credentials
# Password is automatically read from RDS-managed secret if available, otherwise uses var.db_password
# This works during database creation and for all workspaces automatically
resource "aws_secretsmanager_secret_version" "db_credential" {
  secret_id = aws_secretsmanager_secret.db_credential.id

  # Store RDS credentials as JSON
  # Password is automatically synced from RDS-managed secret via data source
  # This eliminates the need for external sync scripts
  secret_string = jsonencode({
    username = local.db_username                    # From RDS-managed secret or var.db_username
    password = local.db_password                    # From RDS-managed secret or var.db_password
    engine   = var.db_engine                        # Database engine (postgres)
    host     = module.database.db_instance_address  # RDS instance address (hostname)
    port     = module.database.db_instance_port     # RDS instance port (from module output)
    dbname   = var.db_name                          # Database name
  })

  # Ensure RDS database is created before secret version
  # The secret needs the RDS endpoint which is only available after the database is created
  depends_on = [
    module.database,
    aws_secretsmanager_secret.db_credential
  ]

  # Ignore changes to secret_string to avoid conflicts with staging labels
  # The password will be updated via the data source on the next apply if needed
  # This prevents Terraform from trying to update a secret that was previously updated by sync script
  lifecycle {
    ignore_changes = [secret_string]
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
          aws_secretsmanager_secret.db_credential.arn,
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
