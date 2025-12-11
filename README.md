# Infrastructure as Code - Client Management Application

Production-ready Terraform infrastructure for deploying a scalable Flask web application with PostgreSQL database on AWS.

## 🏗️ Architecture

- **VPC**: Multi-AZ VPC with public, private, and database subnets
- **RDS PostgreSQL**: Managed database in private subnets
- **Auto Scaling Group**: EC2 instances running Flask application
- **Application Load Balancer**: HTTPS-enabled ALB with SSL certificate
- **S3 Bucket**: Stores application scripts and assets
- **Secrets Manager**: Secure storage of database credentials
- **Route53**: DNS configuration with SSL certificate

## 📁 Repository Structure

```
.
├── README.md                 # This file
├── .gitignore               # Git ignore rules
├── infrastructure-web-app/   # Infrastructure code
│   ├── .github/              # CI/CD workflows
│   │   └── workflows/
│   ├── terraform/            # Terraform configuration
│   │   ├── *.tf             # Main Terraform files
│   │   ├── modules/         # Reusable modules
│   │   │   ├── providers/
│   │   │   └── s3-tfstate-backend/
│   │   └── scripts/         # Bootstrap and userdata scripts
│   └── docs/                 # Documentation
│       ├── WORKSPACES.md
│       ├── GIT_SETUP.md
│       └── PROJECT_IMPROVEMENTS.md
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
- Database in private subnets
- SSL/TLS encryption for database connections
- Security groups with least privilege access

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
