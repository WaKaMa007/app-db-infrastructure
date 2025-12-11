# VPC module for the app_db module

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.1.1"

  name             = var.vpc_name != "" ? var.vpc_name : "${local.name_prefix}-vpc"
  cidr             = var.vpc_cidr
  azs              = var.azs
  public_subnets   = var.public_subnets
  private_subnets  = var.private_subnets
  database_subnets = var.database_subnets

  # Explicitly disable NAT and VPN gateways to avoid dependencies 
  enable_nat_gateway = true
  single_nat_gateway = true
  enable_vpn_gateway = false

  tags = {
    Terraform = "true"
    Name      = "${local.name_prefix}-vpc"
  }
}


module "database" {
  source  = "terraform-aws-modules/rds/aws"
  version = "6.1.0"

  identifier              = "${local.db_prefix}-db"
  engine                  = var.db_engine
  engine_version          = var.db_engine_version
  instance_class          = local.env_config.db_instance_type
  allocated_storage       = 20
  max_allocated_storage   = 100
  storage_encrypted       = true
  backup_retention_period = 7
  backup_window           = "00:00-03:00"

  # Destruction settings - workspace-specific settings
  skip_final_snapshot      = true                                 # Skip final snapshot on destroy (faster cleanup)
  deletion_protection      = local.env_config.deletion_protection # Workspace-specific (true for prod)
  delete_automated_backups = true                                 # Delete automated backups on destroy

  # Disable submodules
  create_db_parameter_group = false
  create_db_option_group    = false

  # 🔑 Integration with VPC
  # Ensure database subnets and security group are in the same VPC
  # Use the DB subnet group created by the VPC module
  db_subnet_group_name   = module.vpc.database_subnet_group_name
  vpc_security_group_ids = [aws_security_group.db-sg.id]

  # Ensure VPC and security group are created before database
  depends_on = [
    module.vpc,
    aws_security_group.db-sg
  ]

  # Uncommented for fresh RDS creation - database will be created automatically
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  # Enable RDS to manage master user password in Secrets Manager
  # This ensures the password is securely managed and rotated by AWS
  manage_master_user_password = true

  tags = {
    Name = "${local.db_prefix}-${local.random_integer}"
  }
}