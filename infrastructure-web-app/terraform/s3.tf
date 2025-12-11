# S3 bucket for storing userdata scripts and other application assets

resource "aws_s3_bucket" "app_assets" {
  bucket        = "${var.s3_bucket_name}-${local.random_integer}"
  force_destroy = true

  tags = {
    Name        = "${local.name_prefix}-assets"
    Environment = var.environment
    Purpose     = "Application assets and userdata scripts"
  }
}

# Enable versioning for userdata scripts
resource "aws_s3_bucket_versioning" "app_assets" {
  bucket = aws_s3_bucket.app_assets.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "app_assets" {
  bucket = aws_s3_bucket.app_assets.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "app_assets" {
  bucket = aws_s3_bucket.app_assets.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Upload userdata script to S3 with template variables injected
# Using templatefile() to inject secret_arn and region into the script
resource "aws_s3_object" "userdata_script" {
  bucket = aws_s3_bucket.app_assets.id
  key    = "scripts/userdata_client_app.sh"
  content = templatefile("${path.module}/scripts/userdata_client_app.sh", {
    secret_arn = aws_secretsmanager_secret.db_credential.arn
    region     = var.region
  })
  content_type = "text/x-shellscript"

  # Use content hash for change detection (best practice)
  etag = md5(templatefile("${path.module}/scripts/userdata_client_app.sh", {
    secret_arn = aws_secretsmanager_secret.db_credential.arn
    region     = var.region
  }))

  tags = {
    Name = "Client App Userdata Script"
    Type = "Userdata"
  }

  depends_on = [
    aws_secretsmanager_secret.db_credential,
    aws_secretsmanager_secret_version.db_credential
  ]
}

# Output bucket name for reference
output "s3_bucket_app_assets" {
  description = "Name of the S3 bucket for application assets"
  value       = aws_s3_bucket.app_assets.id
}

