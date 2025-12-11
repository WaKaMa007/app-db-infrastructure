# Infrastructure as Code - Client Management Application

Production-ready Terraform infrastructure for deploying a scalable Flask web application with PostgreSQL database on AWS.

## 🏗️ Architecture

- **VPC**: Multi-AZ VPC with public, private, and database subnets
- **RDS PostgreSQL**: Managed database in private subnets with automatic password management
- **Auto Scaling Group**: EC2 instances running Flask application (workspace-specific sizing)
- **Application Load Balancer**: HTTPS-enabled ALB with SSL certificate
- **S3 Bucket**: Stores application scripts and assets
- **Secrets Manager**: Secure storage of database credentials (auto-synced from RDS)
- **Route53**: DNS configuration with SSL certificate (workspace-specific subdomains)
- **SSM**: AWS Systems Manager for secure instance access

## 📁 Repository Structure

```
.
├── README.md                        # This file
├── .gitignore                       # Git ignore rules
├── GIT_REMOTE_SETUP.md             # Git remote configuration guide
├── infrastructure-web-app/          # Infrastructure code
│   ├── terraform/                   # Terraform configuration
│   │   ├── *.tf                    # Main Terraform files
│   │   │   ├── workspaces.tf       # Workspace configurations
│   │   │   ├── module.tf           # RDS and VPC modules
│   │   │   ├── autoscaling.tf      # Auto Scaling Group
│   │   │   ├── secret_manager.tf   # Secrets Manager (Terraform-native sync)
│   │   │   ├── loadbalancer.tf     # Application Load Balancer
│   │   │   ├── route53.tf          # DNS configuration
│   │   │   ├── ssl_cert.tf         # SSL certificates
│   │   │   ├── s3.tf               # S3 bucket
│   │   │   ├── ssm.tf              # Systems Manager
│   │   │   └── variables.tf        # Input variables
│   │   ├── modules/                # Reusable modules
│   │   └── scripts/                # Bootstrap and userdata scripts
│   ├── sync-db-password.sh         # Manual password sync script (optional)
│   ├── setup-workspaces.sh         # Workspace setup automation
│   ├── compare-workspaces.sh       # Workspace comparison tool
│   ├── README.md                   # Infrastructure overview
│   ├── WORKSPACE_SETUP.md          # Complete workspace guide
│   ├── DEPLOYMENT_WORKFLOW.md      # Deployment procedures
│   ├── PROMOTION_CHECKLIST.md      # Promotion checklist
│   └── PASSWORD_SYNC_TERRAFORM_NATIVE.md  # Password sync documentation
```

## 🚀 Quick Start

### Prerequisites

- AWS CLI configured
- Terraform >= 1.0
- Access to AWS account

### Initial Setup

```bash
# Navigate to Terraform directory
cd infrastructure-web-app/terraform

# Initialize Terraform
terraform init

# Select workspace
terraform workspace select dev  # or staging/prod

# Review plan
terraform plan

# Apply changes
terraform apply
```

## 🌍 Environments

This project uses Terraform workspaces for environment management:

- **dev** - Development environment (t3.micro instances)
- **staging** - Staging environment (t3.small instances)
- **prod** - Production environment (t3.medium instances, deletion protection enabled)

See [infrastructure-web-app/docs/WORKSPACES.md](infrastructure-web-app/docs/WORKSPACES.md) for detailed workspace documentation.

## 📚 Documentation

- [Workspaces Guide](infrastructure-web-app/docs/WORKSPACES.md) - Environment management
- [Git Setup Guide](infrastructure-web-app/docs/GIT_SETUP.md) - Git workflow and best practices
- [Project Improvements](infrastructure-web-app/docs/PROJECT_IMPROVEMENTS.md) - Future enhancements

## 🔒 Security

- All secrets stored in AWS Secrets Manager
- RDS master password managed by AWS (auto-rotated)
- Database in private subnets (not publicly accessible)
- SSL/TLS encryption for database connections (required)
- Application Load Balancer with HTTPS
- Security groups with least privilege access
- AWS Systems Manager for secure instance access (no SSH keys needed)

## 🤝 Contributing

1. Create a feature branch
2. Make changes in `dev` workspace
3. Test in `staging` workspace
4. Deploy to `prod` workspace
5. Submit pull request

## 📝 License

[Your License Here]

## 👥 Authors

[Your Name/Team]
