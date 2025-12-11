# Terraform Workspaces Guide

This project uses Terraform workspaces to manage multiple environments (dev, staging, prod).

## Workspace Commands

### List workspaces
```bash
terraform workspace list
```

### Create and switch to a workspace
```bash
# Create and switch to dev workspace
terraform workspace new dev

# Create and switch to staging workspace
terraform workspace new staging

# Create and switch to prod workspace
terraform workspace new prod
```

### Switch between workspaces
```bash
terraform workspace select dev
terraform workspace select staging
terraform workspace select prod
```

### Show current workspace
```bash
terraform workspace show
```

### Delete a workspace
```bash
# First switch to another workspace
terraform workspace select dev

# Then delete the workspace
terraform workspace delete staging
```

## Workspace Configuration

Each workspace has different configurations defined in `workspaces.tf`:

### Dev
- Instance type: `t3.micro`
- Min/Max/Desired: 1/2/1
- DB instance: `db.t3.micro`
- Deletion protection: `false`

### Staging
- Instance type: `t3.small`
- Min/Max/Desired: 1/3/2
- DB instance: `db.t3.small`
- Deletion protection: `false`

### Prod
- Instance type: `t3.medium`
- Min/Max/Desired: 2/5/2
- DB instance: `db.t3.medium`
- Deletion protection: `true`

## Workflow

### Initial Setup
```bash
# 1. Initialize Terraform
terraform init

# 2. Create workspaces
terraform workspace new dev
terraform workspace new staging
terraform workspace new prod

# 3. Select dev workspace (default)
terraform workspace select dev
```

### Daily Workflow
```bash
# Work on dev environment
terraform workspace select dev
terraform plan
terraform apply

# Promote to staging
terraform workspace select staging
terraform plan
terraform apply

# Deploy to production
terraform workspace select prod
terraform plan
terraform apply
```

### Important Notes

1. **State Isolation**: Each workspace has its own state file
   - State files are stored separately: `terraform.tfstate.d/<workspace>/`
   - Resources are isolated between environments

2. **Resource Naming**: Resources are automatically prefixed with workspace name
   - Dev: `web-app-dev-*`
   - Staging: `web-app-staging-*`
   - Prod: `web-app-prod-*`

3. **Git Strategy**: 
   - Use feature branches for changes
   - Test in dev workspace first
   - Merge to main after testing
   - Deploy to prod from main branch

4. **State Backend**: Consider using remote state backend (S3) for team collaboration
   - Each workspace can share the same backend
   - State files are automatically separated by workspace name

## Remote State Backend (Optional)

To use remote state with workspaces, update `provider.tf`:

```hcl
terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "app_db/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
```

With S3 backend, state files are automatically prefixed:
- `terraform.tfstate.d/dev/`
- `terraform.tfstate.d/staging/`
- `terraform.tfstate.d/prod/`

