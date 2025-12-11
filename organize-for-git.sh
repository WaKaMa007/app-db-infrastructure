#!/bin/bash
# Script to organize Terraform code into a professional Git repository structure
# Follows HashiCorp and industry best practices

set -e

# Default structure type
STRUCTURE_TYPE="${1:-standard}"

echo "🏗️  Professional Git Repository Structure Organizer"
echo "=================================================="
echo ""

# Function to create standard structure
create_standard_structure() {
    echo "📁 Creating standard professional structure..."
    echo ""
    
    # Create directory structure
    mkdir -p terraform/modules
    mkdir -p terraform/scripts
    mkdir -p docs
    mkdir -p .github/workflows 2>/dev/null || true
    
    echo "✅ Directory structure created:"
    echo "   terraform/"
    echo "   terraform/modules/"
    echo "   terraform/scripts/"
    echo "   docs/"
    echo ""
    
    # Move Terraform files
    echo "📦 Moving Terraform configuration files..."
    TERRAFORM_CONFIG_FILES=(
        "*.tf"
        ".terraform.lock.hcl"
        ".cursorrules"
    )
    
    for pattern in "${TERRAFORM_CONFIG_FILES[@]}"; do
        if ls $pattern 1> /dev/null 2>&1; then
            echo "  → Moving $pattern"
            mv $pattern terraform/ 2>/dev/null || true
        fi
    done
    
    # Move scripts (but not this script itself)
    echo ""
    echo "📦 Moving scripts..."
    SCRIPT_FILES=(
        "userdata_*.sh"
        "prepare-for-git.sh"
    )
    
    for pattern in "${SCRIPT_FILES[@]}"; do
        if ls $pattern 1> /dev/null 2>&1; then
            echo "  → Moving $pattern"
            mv $pattern terraform/scripts/ 2>/dev/null || true
        fi
    done
    
    # Note: organize-for-git.sh will remain in root (or can be moved manually after)
    echo "  → Note: organize-for-git.sh remains in root for future use"
    
    # Move Terraform directories
    echo ""
    echo "📦 Moving Terraform directories..."
    if [ -d "providers" ]; then
        echo "  → Moving providers/"
        mv providers terraform/modules/ 2>/dev/null || true
    fi
    
    if [ -d "s3-tfstate-backend" ]; then
        echo "  → Moving s3-tfstate-backend/"
        mv s3-tfstate-backend terraform/modules/ 2>/dev/null || true
    fi
    
    # Move documentation
    echo ""
    echo "📄 Organizing documentation..."
    DOC_FILES=(
        "WORKSPACES.md"
        "GIT_SETUP.md"
        "PROJECT_IMPROVEMENTS.md"
    )
    
    for doc in "${DOC_FILES[@]}"; do
        if [ -f "$doc" ]; then
            echo "  → Moving $doc to docs/"
            mv "$doc" docs/
        fi
    done
    
    # Keep README.md in root, but create one in terraform/ if needed
    if [ -f "README.md" ]; then
        echo "  → Keeping README.md in root (standard practice)"
        # Create a terraform-specific README
        if [ ! -f "terraform/README.md" ]; then
            cat > terraform/README.md << 'EOF'
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
EOF
            echo "  → Created terraform/README.md"
        fi
    fi
    
    # Create .github/workflows if it doesn't exist
    if [ ! -d ".github/workflows" ]; then
        mkdir -p .github/workflows
        echo "  → Created .github/workflows/ directory"
    fi
    
    # Create example CI/CD workflow
    if [ ! -f ".github/workflows/terraform.yml" ]; then
        cat > .github/workflows/terraform.yml << 'EOF'
name: Terraform CI/CD

on:
  push:
    branches: [ main, develop ]
    paths:
      - 'terraform/**'
  pull_request:
    branches: [ main ]
    paths:
      - 'terraform/**'

jobs:
  terraform:
    name: Terraform Plan/Apply
    runs-on: ubuntu-latest
    
    defaults:
      run:
        working-directory: ./terraform
    
    steps:
      - name: Checkout
        uses: actions/checkout@v3
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: 1.6.0
      
      - name: Terraform Init
        run: terraform init
      
      - name: Terraform Format Check
        run: terraform fmt -check
      
      - name: Terraform Validate
        run: terraform validate
      
      - name: Terraform Plan
        run: terraform plan -no-color
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
EOF
        echo "  → Created example CI/CD workflow (.github/workflows/terraform.yml)"
    fi
    
    # Update root README if it exists
    if [ -f "README.md" ]; then
        # Backup original
        cp README.md README.md.backup
        
        # Create professional root README
        cat > README.md << 'EOF'
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
├── .github/                  # CI/CD workflows
│   └── workflows/
├── terraform/                # Terraform configuration
│   ├── *.tf                 # Main Terraform files
│   ├── modules/             # Reusable modules
│   │   ├── providers/
│   │   └── s3-tfstate-backend/
│   └── scripts/             # Bootstrap and userdata scripts
└── docs/                     # Documentation
    ├── WORKSPACES.md
    ├── GIT_SETUP.md
    └── PROJECT_IMPROVEMENTS.md
```

## 🚀 Quick Start

### Prerequisites

- AWS CLI configured
- Terraform >= 1.0
- Access to AWS account

### Initial Setup

```bash
# Navigate to Terraform directory
cd terraform

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

See [docs/WORKSPACES.md](docs/WORKSPACES.md) for detailed workspace documentation.

## 📚 Documentation

- [Workspaces Guide](docs/WORKSPACES.md) - Environment management
- [Git Setup Guide](docs/GIT_SETUP.md) - Git workflow and best practices
- [Project Improvements](docs/PROJECT_IMPROVEMENTS.md) - Future enhancements

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
EOF
        echo "  → Updated root README.md (backup saved as README.md.backup)"
    fi
}

# Function to create minimal structure
create_minimal_structure() {
    echo "📁 Creating minimal structure..."
    echo ""
    
    mkdir -p terraform
    
    echo "📦 Moving all Terraform files to terraform/..."
    mv *.tf terraform/ 2>/dev/null || true
    mv *.sh terraform/ 2>/dev/null || true
    mv .terraform.lock.hcl terraform/ 2>/dev/null || true
    mv .cursorrules terraform/ 2>/dev/null || true
    
    if [ -d "providers" ]; then
        mv providers terraform/
    fi
    
    if [ -d "s3-tfstate-backend" ]; then
        mv s3-tfstate-backend terraform/
    fi
    
    echo "✅ Minimal structure created"
}

# Main execution
case "$STRUCTURE_TYPE" in
    standard|prof|professional)
        create_standard_structure
        ;;
    minimal|simple)
        create_minimal_structure
        ;;
    *)
        echo "Usage: $0 [standard|minimal]"
        echo ""
        echo "Structure types:"
        echo "  standard (default) - Professional structure with modules/, scripts/, docs/, CI/CD"
        echo "  minimal           - Simple structure with just terraform/ folder"
        echo ""
        exit 1
        ;;
esac

echo ""
echo "✅ Organization complete!"
echo ""
echo "📋 Final Structure:"
tree -L 3 -I '.terraform|.git' 2>/dev/null || find . -maxdepth 3 -not -path '*/\.*' -type d | head -20
echo ""
echo "📋 Next Steps:"
echo "  1. Review the structure:"
echo "     ls -la terraform/"
echo ""
echo "  2. Update any path references if needed"
echo ""
echo "  3. Stage and commit:"
echo "     git add ."
echo "     git commit -m 'chore: Organize code into professional Git structure'"
echo "     git push"
echo ""
echo "  4. If you moved README.md, review README.md.backup for any content to merge"
echo ""
