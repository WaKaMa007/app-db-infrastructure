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

variable "hosted_zone_name" {
  description = "Name of the hosted zone"
  type        = string
  default     = "555458746908.realhandsonlabs.net"
}

variable "db_username" {
  description = "Username for the database"
  type        = string
  default     = "dbadmin"
}

variable "db_password" {
  description = "Password for the database"
  type        = string
  default     = "password"
}