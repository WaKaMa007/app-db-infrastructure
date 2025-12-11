# Terraform Infrastructure

This directory contains the Terraform configuration for the infrastructure.

## Structure

```
terraform/
├── *.tf              # Main Terraform configuration files
├── modules/          # Reusable Terraform modules
│   ├── providers/
│   └── s3-tfstate-backend/
└── scripts/          # Helper scripts (userdata, bootstrap, etc.)
```

## Usage

```bash
# Navigate to terraform directory
cd terraform

# Initialize Terraform
terraform init

# Select workspace
terraform workspace select dev    # or staging/prod

# Plan changes
terraform plan

# Apply changes
terraform apply

# Destroy (be careful!)
terraform destroy
```

## Workspaces

This project uses Terraform workspaces for environment management:
- `dev` - Development environment
- `staging` - Staging environment  
- `prod` - Production environment

See `../docs/WORKSPACES.md` for detailed workspace documentation.
