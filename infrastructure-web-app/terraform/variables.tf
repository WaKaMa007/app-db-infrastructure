# Variables for the app_db module

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "vpc_name" {
  type        = string
  default     = "" # Will be set based on workspace via locals if empty
  description = "VPC name. If empty, uses workspace-based naming via local.name_prefix"
}

variable "azs" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b"]
}

variable "public_subnets" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnets" {
  type    = list(string)
  default = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "database_subnets" {
  type    = list(string)
  default = ["10.0.81.0/24", "10.0.82.0/24"]
}

variable "database_subnet_group_name" {
  type    = string
  default = "dev-subnet-group"
}

variable "database_subnet_group_description" {
  type    = string
  default = "App DB subnet group"
}

variable "environment" {
  type        = string
  default     = "dev"
  description = "Environment name (dev/staging/prod). If using workspaces, this is overridden by workspace name."

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod"
  }
}

variable "project_name" {
  type    = string
  default = "dev-web-app"
}

variable "company_name" {
  type    = string
  default = "WaKaMa Org"
}

variable "name_prefix" {
  type    = string
  default = "web-app"
}

variable "instance_type" {
  type    = string
  default = "t3.medium"
}

variable "db_instance_type" {
  type    = string
  default = "db.t3.micro"
}

variable "db_engine" {
  type    = string
  default = "postgres"
}

variable "db_engine_version" {
  type    = string
  default = "16.11"
}

variable "db_name" {
  type    = string
  default = "app_db"
}

variable "min_size" {
  description = "Minimum number of instances in ASG"
  type        = string
  default     = "2"
}

variable "max_size" {
  description = "Maximum number of instances in ASG"
  type        = string
  default     = "4"
}

variable "desired_capacity" {
  description = "Desired number of instances in ASG"
  type        = string
  default     = "2"
}

variable "s3_bucket_name" {
  description = "Name of the S3 bucket"
  type        = string
  default     = "dev-web-app"
}

variable "deletion_protection" {
  description = "Enable deletion protection for RDS database (prevents accidental deletion)"
  type        = bool
  default     = true # null means use workspace-specific default
}

variable "force_delete_secret" {
  description = "Force delete the secret"
  type        = bool
  default     = true
}


variable "hosted_zone_name" {
  description = "Name of the hosted zone"
  type        = string
  default     = "006207983642.realhandsonlabs.net"  # This is the hosted zone name for the domain
}

variable "db_username" {
  description = "Username for the database"
  type        = string
  # No default - must be provided via terraform.tfvars or -var flag
  # Example: db_username = "dbadmin"
  sensitive = false
}

variable "db_password" {
  description = "Password for the database (use terraform.tfvars or environment variable, never commit to git)"
  type        = string
  # No default - must be provided via terraform.tfvars (gitignored) or -var flag
  # Example: db_password = "your-secure-password-here"
  sensitive = true # Marks as sensitive to prevent output in logs
}

# ============================================================================
# CloudWatch Alarms Configuration
# ============================================================================

variable "alarm_email" {
  description = "Email address to receive CloudWatch alarm notifications (leave empty to disable notifications)"
  type        = string
  default     = ""
}

# EC2 Alarm Thresholds
variable "alarm_cpu_threshold" {
  description = "Threshold for EC2 CPU utilization alarm (percentage)"
  type        = number
  default     = 80
}

variable "alarm_cpu_low_threshold" {
  description = "Threshold for EC2 low CPU utilization alarm (percentage, for cost optimization)"
  type        = number
  default     = 10
}

# RDS Alarm Thresholds
variable "alarm_rds_cpu_threshold" {
  description = "Threshold for RDS CPU utilization alarm (percentage)"
  type        = number
  default     = 80
}

variable "alarm_rds_connections_threshold" {
  description = "Threshold for RDS database connections alarm"
  type        = number
  default     = 80 # Adjust based on your db instance type and max_connections
}

variable "alarm_rds_free_storage_threshold" {
  description = "Threshold for RDS free storage alarm (bytes, e.g., 10737418240 = 10 GB)"
  type        = number
  default     = 10737418240 # 10 GB
}

variable "alarm_rds_memory_threshold" {
  description = "Threshold for RDS freeable memory alarm (bytes, alerts when below this)"
  type        = number
  default     = 268435456 # 256 MB (adjust based on your instance type)
}

# ALB Alarm Thresholds
variable "alarm_alb_5xx_threshold" {
  description = "Threshold for ALB HTTP 5xx errors alarm (count)"
  type        = number
  default     = 10 # Alert if 10+ 5xx errors in 5 minutes
}

variable "alarm_alb_4xx_threshold" {
  description = "Threshold for ALB HTTP 4xx errors alarm (count)"
  type        = number
  default     = 100 # Alert if 100+ 4xx errors in 5 minutes
}

variable "alarm_alb_response_time_threshold" {
  description = "Threshold for ALB target response time alarm (seconds)"
  type        = number
  default     = 2.0 # Alert if average response time > 2 seconds
}

# ============================================================================
# Prometheus Configuration
# ============================================================================

variable "enable_prometheus_config_backup" {
  description = "Enable backup of Prometheus configuration to S3"
  type        = bool
  default     = false
}