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

# Local values for database credentials
# We use var.db_password and var.db_username directly to avoid count argument issues
# RDS manages its own secret separately when manage_master_user_password = true
# Our custom secret uses the password we provide, which matches what RDS uses initially
locals {
  db_password = var.db_password
  db_username = var.db_username
}

# Secret version with actual credentials
# Uses var.db_password which matches the password provided to RDS
# RDS also manages its own secret separately (when manage_master_user_password = true)
# Both secrets will have the same password since RDS uses the password we provide initially
resource "aws_secretsmanager_secret_version" "db_credential" {
  secret_id = aws_secretsmanager_secret.db_credential.id

  # Store RDS credentials as JSON
  # Password matches var.db_password which is what RDS uses
  secret_string = jsonencode({
    username = local.db_username                   # From var.db_username
    password = local.db_password                   # From var.db_password (matches RDS)
    engine   = var.db_engine                       # Database engine (postgres)
    host     = module.database.db_instance_address # RDS instance address (hostname)
    port     = module.database.db_instance_port    # RDS instance port (from module output)
    dbname   = var.db_name                         # Database name
  })

  # Ensure RDS database is created before secret version
  # The secret needs the RDS endpoint which is only available after the database is created
  depends_on = [
    module.database,
    aws_secretsmanager_secret.db_credential
  ]

  # Ignore changes to secret_string to prevent Terraform from updating after initial creation
  # This avoids conflicts with staging labels and allows manual updates if needed
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
