# Terraform Workspaces Configuration
# This file helps manage different environments using Terraform workspaces

# Workspace-specific local values
locals {
  # Valid workspaces
  valid_workspaces = ["dev", "staging", "prod"]

  # Current workspace (defaults to "dev" if not set)
  current_workspace = terraform.workspace

  # Environment-specific configurations
  workspace_config = {
    dev = {
      instance_type       = "t3.micro"
      min_size            = "1"
      max_size            = "2"
      desired_capacity    = "1"
      db_instance_type    = "db.t3.micro"
      deletion_protection = false
    }
    staging = {
      instance_type       = "t3.small"
      min_size            = "1"
      max_size            = "3"
      desired_capacity    = "2"
      db_instance_type    = "db.t3.small"
      deletion_protection = false
    }
    prod = {
      instance_type       = "t3.medium"
      min_size            = "2"
      max_size            = "5"
      desired_capacity    = "2"
      db_instance_type    = "db.t3.medium"
      deletion_protection = true
    }
  }

  # Get current workspace config, default to dev if invalid
  # Check if current workspace is in valid list
  workspace_valid = contains(local.valid_workspaces, local.current_workspace)
  env_config      = local.workspace_config[local.workspace_valid ? local.current_workspace : "dev"]
}

