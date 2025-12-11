# Security Group for the app_db module

# Security Group for the Application Load Balancer
resource "aws_security_group" "alb-sg" {
  name        = "${local.name_prefix}-alb-sg"
  description = "Security Group for the Application Load Balancer"
  vpc_id      = module.vpc.vpc_id

  lifecycle {
    create_before_destroy = true
  }

  # Allow HTTPS from internet
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTPS from internet"
  }

  # Allow HTTP from internet (for redirects)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP from internet"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "${local.name_prefix}-alb-sg"
  }
}

# Security Group for the EC2 instances (app servers)
resource "aws_security_group" "app-server-sg" {
  name        = "${local.name_prefix}-instance-sg"
  description = "Security Group for the app-server instances"
  vpc_id      = module.vpc.vpc_id

  lifecycle {
    create_before_destroy = true
  }

  # Allow HTTP from ALB only (for health checks and traffic)
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb-sg.id]
    description     = "Allow HTTP from ALB"
  }

  # Allow HTTPS from ALB (if ALB forwards HTTPS traffic)
  # Note: ALB typically communicates with instances over HTTP internally
  # This rule is included for completeness if HTTPS termination is needed
  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.alb-sg.id]
    description     = "Allow HTTPS from ALB"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "${local.name_prefix}-instance-sg"
  }
}

resource "aws_security_group" "db-sg" {
  name        = "${local.name_prefix}-db-sg"
  description = "Security Group for the database"
  vpc_id      = module.vpc.vpc_id

  lifecycle {
    create_before_destroy = true
  }

  # Allow PostgreSQL connections from app servers only
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app-server-sg.id]
    description     = "Allow PostgreSQL access from app servers"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    name = local.name_prefix
  }
}
