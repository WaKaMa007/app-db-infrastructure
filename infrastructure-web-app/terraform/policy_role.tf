# Policy and Role for the dev-web-app module

# Create the policy for the app-server-role to access the S3 bucket and Secrets Manager
resource "aws_iam_policy" "app-server-policy" {
  name = "${local.name_prefix}-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion"
        ]
        Resource = "${aws_s3_bucket.app_assets.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.app_assets.arn
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = aws_secretsmanager_secret.db_credential.arn
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:StartSession"
        ]
        Resource = [
          "arn:aws:ec2:*:*:instance/*",
          "arn:aws:ssm:*:*:document/AWS-StartSSHSession",
          "arn:aws:ssm:*:*:document/SSM-SessionManagerRunShell"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:DescribeInstanceInformation",
          "ssm:DescribeInstanceProperties",
          "ssm:DescribeSessions",
          "ssm:GetConnectionStatus"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceStatus",
          "ec2:DescribeInstanceAttribute"
        ]
        Resource = "*"
      }
    ]
  })

  depends_on = [
    aws_s3_bucket.app_assets,
    aws_secretsmanager_secret.db_credential
  ]
}

# Create the role for the app-server-policy
resource "aws_iam_role" "app-server-role" {
  name = "${local.name_prefix}-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
  tags = {
    name = "${local.name_prefix}-role"
  }
}

# Create the instance profile for the app-server-role
resource "aws_iam_instance_profile" "app-server-instance-profile" {
  name = "${local.name_prefix}-instance-profile"
  role = aws_iam_role.app-server-role.name
  tags = {
    name = "${local.name_prefix}-instance-profile"
  }
}

# Attach the custom app-server policy to the role
resource "aws_iam_role_policy_attachment" "app-server-role-policy-attachment" {
  role       = aws_iam_role.app-server-role.name
  policy_arn = aws_iam_policy.app-server-policy.arn
}

# Attach the SSM policy to the app-server-role
resource "aws_iam_role_policy_attachment" "app-server-role-ssm-attachment" {
  role       = aws_iam_role.app-server-role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}