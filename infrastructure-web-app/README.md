# Infrastructure Web App - Terraform Workspaces Project

A professional infrastructure-as-code project demonstrating Terraform workspace management for multi-environment deployments (dev, staging, prod).

## 🎯 Project Overview

This project showcases:
- **Multi-environment infrastructure** management using Terraform workspaces
- **Environment promotion workflow** (dev → staging → prod)
- **Infrastructure as Code** best practices
- **AWS cloud resources** (VPC, RDS, EC2, ALB, Auto Scaling)
- **GitOps integration** with version-controlled infrastructure

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     AWS Infrastructure                   │
│                                                          │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐         │
│  │   DEV    │    │ STAGING  │    │   PROD   │         │
│  │          │    │          │    │          │         │
│  │ t3.micro │───▶│t3.small  │───▶│t3.medium │         │
│  │ 1-2 inst │    │ 1-3 inst │    │ 2-5 inst │         │
│  │ db.t3.micro│  │db.t3.small│   │db.t3.medium│        │
│  └──────────┘    └──────────┘    └──────────┘         │
│                                                          │
│  Components:                                             │
│  • VPC with public/private/database subnets             │
│  • RDS PostgreSQL (private subnets)                     │
│  • Auto Scaling Group (EC2 instances)                   │
│  • Application Load Balancer (HTTPS)                    │
│  • Route53 DNS (workspace-specific domains)             │
│  • Secrets Manager (auto-synced passwords)              │
│  • S3 bucket (application assets)                       │
│  • AWS Systems Manager (secure access)                  │
└─────────────────────────────────────────────────────────┘
```

## 📁 Project Structure

```
infrastructure-web-app/
├── terraform/
│   ├── workspaces.tf          # Workspace configurations
│   ├── module.tf              # RDS and VPC modules
│   ├── autoscaling.tf         # EC2 Auto Scaling Group
│   ├── loadbalancer.tf        # Application Load Balancer
│   ├── secret_manager.tf      # AWS Secrets Manager (Terraform-native password sync)
│   ├── route53.tf             # DNS configuration
│   ├── ssl_cert.tf            # SSL certificates
│   ├── s3.tf                  # S3 bucket
│   ├── ssm.tf                 # Systems Manager
│   ├── sg.tf                  # Security groups
│   ├── variables.tf           # Input variables
│   ├── output.tf              # Output values
│   ├── ami.tf                 # AMI data source
│   ├── provider.tf            # Provider configuration
│   ├── policy_role.tf         # IAM roles and policies
│   ├── locals.tf              # Local values
│   └── scripts/               # Bootstrap and userdata scripts
├── sync-db-password.sh        # Manual password sync (optional fallback)
├── setup-workspaces.sh        # Workspace setup automation
├── compare-workspaces.sh      # Workspace comparison tool
├── README.md                  # This file
├── WORKSPACE_SETUP.md         # Complete workspace guide
├── PROMOTION_CHECKLIST.md     # Deployment checklist
├── DEPLOYMENT_WORKFLOW.md     # Workflow documentation
└── PASSWORD_SYNC_TERRAFORM_NATIVE.md  # Password sync documentation
```

## 🚀 Quick Start

### Prerequisites

- Terraform >= 1.0
- AWS CLI configured
- AWS credentials with appropriate permissions

### Setup

1. **Clone and navigate:**
   ```bash
   cd infrastructure-web-app/terraform
   ```

2. **Set up workspaces:**
   ```bash
   cd ..
   ./setup-workspaces.sh
   ```

3. **Deploy to dev:**
   ```bash
   cd terraform
   terraform workspace select dev
   terraform init
   terraform plan
   terraform apply
   ```

## 🔄 Promotion Workflow

### Standard Flow

```
┌─────┐      ┌─────────┐      ┌─────┐      ┌─────┐
│ Dev │ ───> │ Staging │ ───> │ Prod │ ───> │ Git │
└─────┘      └─────────┘      └─────┘      └─────┘
```

1. **Develop** in DEV workspace
2. **Test** thoroughly
3. **Promote** to STAGING
4. **Validate** in STAGING
5. **Promote** to PROD
6. **Commit** to Git

### Quick Commands

```bash
# Switch workspaces
terraform workspace select dev
terraform workspace select staging
terraform workspace select prod

# Deploy
terraform plan
terraform apply

# Check status
terraform workspace show
terraform state list
```

## 📚 Documentation

- **[WORKSPACE_SETUP.md](WORKSPACE_SETUP.md)** - Complete workspace setup and migration guide
- **[PROMOTION_CHECKLIST.md](PROMOTION_CHECKLIST.md)** - Step-by-step deployment checklist
- **[DEPLOYMENT_WORKFLOW.md](DEPLOYMENT_WORKFLOW.md)** - Detailed deployment procedures

## 🔧 Configuration

### Environment-Specific Settings

| Setting | DEV | STAGING | PROD |
|---------|-----|---------|------|
| Instance Type | t3.micro | t3.small | t3.medium |
| Min Instances | 1 | 1 | 2 |
| Max Instances | 2 | 3 | 5 |
| Desired Capacity | 1 | 2 | 2 |
| DB Instance | db.t3.micro | db.t3.small | db.t3.medium |
| Deletion Protection | ❌ | ❌ | ✅ |

## 🎓 Learning Objectives

This project demonstrates:

- ✅ **Terraform Workspaces** - Managing multiple environments
- ✅ **Infrastructure as Code** - Version-controlled infrastructure
- ✅ **Environment Promotion** - Safe deployment workflows
- ✅ **AWS Services** - VPC, RDS, EC2, ALB, Auto Scaling
- ✅ **Secrets Management** - AWS Secrets Manager integration
- ✅ **GitOps** - Infrastructure changes in version control
- ✅ **Best Practices** - Production-ready patterns

## 💡 Key Features

- **Multi-environment support** with workspace isolation
- **Automated password sync** for RDS credentials (Terraform-native, no external scripts)
- **Environment-specific configurations** for resource sizing
- **Production safety** with deletion protection
- **Workspace-specific DNS** (dev.example.com, staging.example.com, prod.example.com)
- **Complete documentation** for team collaboration
- **Secure access** via AWS Systems Manager (no SSH keys needed)

## 📋 Usage Examples

### Making a Change

```bash
# 1. Work in DEV
terraform workspace select dev
# Make changes...
terraform apply

# 2. Promote to STAGING
terraform workspace select staging
terraform apply

# 3. Promote to PROD
terraform workspace select prod
terraform apply

# 4. Commit
git add .
git commit -m "feat: Description of changes"
git push
```

## 🛠️ Maintenance

### Password Sync

Password synchronization is now handled automatically by Terraform using a data source. The password is synced from the RDS-managed secret during `terraform apply`.

If manual sync is needed (e.g., after manual password rotation):

```bash
./sync-db-password.sh
```

See [PASSWORD_SYNC_TERRAFORM_NATIVE.md](PASSWORD_SYNC_TERRAFORM_NATIVE.md) for details.

### State Management

Each workspace maintains separate state:
- `terraform.tfstate.d/dev/terraform.tfstate`
- `terraform.tfstate.d/staging/terraform.tfstate`
- `terraform.tfstate.d/prod/terraform.tfstate`

## 🎯 Showcase Highlights

Perfect for demonstrating to recruiters:

- **Professional structure** - Well-organized, documented codebase
- **Real-world patterns** - Industry-standard workflows
- **Complete documentation** - Easy to understand and follow
- **Best practices** - Production-ready implementation
- **Multi-environment** - Shows understanding of dev/staging/prod

## 📝 License

This is a demonstration project for portfolio/recruitment purposes.

## 🤝 Contributing

This is a personal showcase project. Feel free to use it as a reference for your own projects!

---

**Built with ❤️ using Terraform and AWS**

