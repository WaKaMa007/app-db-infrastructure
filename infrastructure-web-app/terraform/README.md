# Terraform Infrastructure

This directory contains the Terraform configuration for the infrastructure.

## Structure

```
terraform/
├── workspaces.tf          # Workspace-specific configurations
├── module.tf              # RDS and VPC module definitions
├── autoscaling.tf         # EC2 Auto Scaling Group configuration
├── loadbalancer.tf        # Application Load Balancer
├── secret_manager.tf      # AWS Secrets Manager (Terraform-native password sync)
├── route53.tf             # Route53 DNS records
├── ssl_cert.tf            # ACM SSL certificates
├── s3.tf                  # S3 bucket for application assets
├── ssm.tf                 # AWS Systems Manager configuration
├── sg.tf                  # Security groups
├── variables.tf           # Input variables
├── output.tf              # Output values
├── ami.tf                 # AMI data source
├── provider.tf            # AWS provider configuration
├── policy_role.tf         # IAM roles and policies
├── locals.tf              # Local computed values
├── modules/               # Reusable Terraform modules
│   └── s3-tfstate-backend/
└── scripts/               # Helper scripts (userdata, bootstrap, etc.)
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
