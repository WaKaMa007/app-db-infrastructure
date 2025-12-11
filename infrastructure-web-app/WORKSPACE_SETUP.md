# Terraform Workspaces - Complete Workflow Guide

## Overview

This project uses Terraform workspaces to manage three environments: **dev**, **staging**, and **prod**. Each workspace has environment-specific configurations for instance types, scaling, and deletion protection.

### Workspace Configurations

| Environment | Instance Type | Min | Max | Desired | DB Instance | Deletion Protection |
|------------|---------------|-----|-----|---------|-------------|---------------------|
| **dev** | t3.micro | 1 | 2 | 1 | db.t3.micro | ❌ Disabled |
| **staging** | t3.small | 1 | 3 | 2 | db.t3.small | ❌ Disabled |
| **prod** | t3.medium | 2 | 5 | 2 | db.t3.medium | ✅ Enabled |

---

## Part 1: Migrating Existing Resources to Dev Workspace

### Step 1: Create Dev Workspace

```bash
cd infrastructure-web-app/terraform

# Create and switch to dev workspace
terraform workspace new dev
terraform workspace select dev
```

### Step 2: Import Existing Resources

Since your infrastructure already exists in the `default` workspace, you'll need to import the resources into the `dev` workspace. **Important**: The resources will keep the same names (`web-app-dev-*`) since the naming logic uses the workspace name.

#### Option A: Import All Resources (Recommended for Clean State)

```bash
# List all resources in current state
terraform state list > resources.txt

# For each resource, import using this pattern:
# terraform import <resource_type>.<resource_name> <aws_resource_id>
```

#### Option B: Move State (Simpler)

```bash
# Back up current state
cp terraform.tfstate terraform.tfstate.backup

# Move state files
mkdir -p terraform.tfstate.d/dev
mv terraform.tfstate terraform.tfstate.d/dev/terraform.tfstate 2>/dev/null || true

# Now Terraform will use the dev workspace state
terraform workspace select dev
terraform state list  # Should show your resources
```

#### Option C: Fresh Start (Cleanest for Showcase)

If you want a clean demonstration, you can:

```bash
# 1. Destroy current infrastructure (in default workspace)
terraform workspace select default
terraform destroy  # ⚠️ Only if you're okay destroying current setup

# 2. Create dev workspace
terraform workspace new dev
terraform workspace select dev

# 3. Apply fresh
terraform init
terraform plan
terraform apply
```

**For showcasing to recruiters, Option C (fresh start) is recommended** as it demonstrates clean workspace usage from the beginning.

---

## Part 2: Setting Up All Three Environments

### Initial Setup

```bash
cd infrastructure-web-app/terraform

# 1. Create all workspaces
terraform workspace new dev
terraform workspace new staging
terraform workspace new prod

# 2. List workspaces
terraform workspace list
```

### Deploy Each Environment

**Important:** Each workspace maintains its own separate state. If a workspace is empty (0 resources), `terraform apply` will CREATE all resources. If resources already exist, it will UPDATE them.

```bash
# Deploy DEV environment
terraform workspace select dev
terraform init
terraform plan  # Review changes
terraform apply  # Type 'yes' when prompted

# Deploy STAGING environment
terraform workspace select staging
terraform init
terraform plan  # Review changes - will show ~47 resources to add if empty
terraform apply  # Type 'yes' when prompted - this CREATES all resources in AWS

# Deploy PROD environment (with deletion protection)
terraform workspace select prod
terraform init
terraform plan  # Review changes - should show deletion_protection = true
terraform apply  # Type 'yes' when prompted
```

**Expected Output Differences:**

**Empty Workspace (e.g., staging with 0 resources):**
```
Plan: 47 to add, 0 to change, 0 to destroy.
Do you want to perform these actions?
  Enter a value: yes

Apply complete! Resources: 47 added, 0 changed, 0 destroyed.
```

**Workspace with Existing Resources (e.g., prod with 47 resources):**
```
Plan: 0 to add, 0 to change, 0 to destroy.

Apply complete! Resources: 0 added, 0 changed, 0 destroyed.
```

**Note:** Both `terraform apply` commands work the same way - they both provision/update infrastructure in AWS. The difference is whether resources already exist or not.

---

## Part 3: Promotion Workflow (Dev → Staging → Prod)

### Workflow Overview

```
┌─────┐      ┌─────────┐      ┌─────┐      ┌─────┐
│ Dev │ ───> │ Staging │ ───> │ Prod │ ───> │ Git │
└─────┘      └─────────┘      └─────┘      └─────┘
  ↓             ↓               ↓
Test          Validate       Release
```

### Step-by-Step Promotion Process

#### 1. Develop and Test in DEV

```bash
# Switch to dev workspace
terraform workspace select dev

# Make your changes to Terraform files
# Edit: module.tf, autoscaling.tf, sg.tf, etc.

# Plan and apply in dev
terraform plan
terraform apply

# Test your changes thoroughly
# - Access application
# - Test database connectivity
# - Verify all services work correctly
```

#### 2. Promote to STAGING

```bash
# Ensure dev is stable and tested
terraform workspace select dev
terraform show  # Review current state

# Switch to staging
terraform workspace select staging

# Plan to see what will change
terraform plan

# Review the plan carefully:
# - Instance types should change (dev: t3.micro → staging: t3.small)
# - Scaling should change (dev: 1-2 → staging: 1-3)
# - Other configurations should match your changes

# Apply to staging
terraform apply

# Validate in staging environment
# - Test application functionality
# - Load testing if applicable
# - Integration testing
```

#### 3. Promote to PROD

```bash
# Only promote to prod after staging validation passes

# Switch to prod workspace
terraform workspace select prod

# Plan carefully - prod has deletion protection!
terraform plan

# Review critical differences:
# - Instance type: t3.medium (more resources)
# - Scaling: 2-5 instances (higher capacity)
# - Deletion protection: true (safety!)
# - All your changes should be included

# Apply to prod
terraform apply

# Post-deployment validation
# - Monitor application health
# - Check CloudWatch metrics
# - Verify database performance
```

#### 4. Commit to Git (After PROD Success)

```bash
# Ensure prod deployment is successful and stable

# Navigate to project root
cd /home/wakama/terra/projects/learn-terra/app_db

# Review all changes
git status
git diff

# Stage changes
git add .

# Commit with descriptive message
git commit -m "feat: [Description of changes] - Promoted from dev through staging to prod

- [Feature 1]: Description
- [Feature 2]: Description
- Deployed to: dev → staging → prod
- All environments validated successfully"

# Push to repository
git push origin main  # or your branch name
```

---

## Part 4: Git Workflow Best Practices

### Branch Strategy (Recommended)

```
main (production-ready code)
  ├── develop (integration branch)
  │     ├── feature/terraform-improvements
  │     ├── feature/new-feature
  │     └── fix/bug-fix
  └── hotfix/critical-fix
```

### Typical Git Workflow

```bash
# 1. Create feature branch from main
git checkout main
git pull origin main
git checkout -b feature/new-infrastructure-change

# 2. Make changes and test in DEV
cd infrastructure-web-app/terraform
terraform workspace select dev
# Make changes...
terraform plan
terraform apply
# Test thoroughly

# 3. Promote through environments
terraform workspace select staging
terraform apply
# Validate...

terraform workspace select prod
terraform apply
# Validate...

# 4. Commit and push
git add .
git commit -m "feat: [Feature description]"
git push origin feature/new-infrastructure-change

# 5. Create Pull Request (if using GitHub/GitLab)
# Review → Merge to main
```

### Commit Message Convention

Use conventional commits for clarity:

```
feat: Add auto-scaling based on CPU utilization
fix: Resolve database connection timeout issue
docs: Update deployment workflow documentation
refactor: Simplify workspace configuration
chore: Update Terraform provider versions
```

**Example for recruiters:**

```bash
git commit -m "feat: Implement multi-environment deployment with Terraform workspaces

- Added dev, staging, and prod workspace configurations
- Implemented environment-specific resource sizing
- Added deletion protection for production environment
- Documented complete promotion workflow

Deployment status:
✅ DEV: Tested and validated
✅ STAGING: Validated with load testing
✅ PROD: Deployed and monitored successfully"
```

---

## Part 5: Daily Workflow Examples

### Making a New Change

```bash
# 1. Start in DEV
terraform workspace select dev
terraform plan
terraform apply

# 2. Test and validate
# ... testing ...

# 3. Promote if successful
terraform workspace select staging
terraform apply
# Validate...

terraform workspace select prod
terraform apply
# Validate...

# 4. Commit
git add .
git commit -m "feat: Your change description"
git push
```

### Hotfix Process

```bash
# 1. Create hotfix branch
git checkout -b hotfix/critical-security-patch

# 2. Fix in DEV first (still test!)
terraform workspace select dev
# Apply fix...
terraform apply

# 3. Immediately promote to PROD (skipping staging for urgency)
terraform workspace select prod
terraform apply

# 4. Then backfill to staging
terraform workspace select staging
terraform apply

# 5. Commit and merge
git add .
git commit -m "hotfix: Critical security patch - CVE-XXXX-XXXX"
git push
```

### Checking Current State

```bash
# See current workspace
terraform workspace show

# List all workspaces
terraform workspace list

# Check state in current workspace
terraform state list

# Show current configuration
terraform show
```

---

## Part 6: Showcasing to Recruiters

### Key Points to Highlight

1. **Environment Separation**
   - Clear separation between dev, staging, and prod
   - Different resource configurations per environment
   - Production safety features (deletion protection)

2. **Infrastructure as Code**
   - Version-controlled infrastructure
   - Repeatable deployments
   - Consistent environments

3. **Best Practices**
   - Promotion workflow (dev → staging → prod)
   - Git integration
   - Automated password synchronization
   - Workspace-based resource management

4. **Production Readiness**
   - Deletion protection in prod
   - Appropriate scaling for each environment
   - Security groups and network isolation
   - Secrets management

### Demonstration Script

```bash
# Show workspace setup
terraform workspace list

# Show dev configuration
terraform workspace select dev
terraform plan | grep -E "instance_type|min_size|max_size|deletion_protection"

# Show staging configuration
terraform workspace select staging
terraform plan | grep -E "instance_type|min_size|max_size|deletion_protection"

# Show prod configuration (highlight safety)
terraform workspace select prod
terraform plan | grep -E "instance_type|min_size|max_size|deletion_protection"

# Show state isolation
terraform state list  # Each workspace has separate state
```

### Portfolio Talking Points

- ✅ **Multi-Environment Management**: Demonstrates understanding of dev/staging/prod workflows
- ✅ **Infrastructure as Code**: Shows Terraform expertise with real-world patterns
- ✅ **GitOps**: Integration of infrastructure changes with version control
- ✅ **Best Practices**: Deletion protection, appropriate resource sizing, security
- ✅ **Automation**: Terraform-native password sync, workspace management, deployment workflows

---

## Part 7: Troubleshooting

### Common Issues

#### Issue: Staging Shows Changes But Doesn't Create Resources

**Symptoms:**
- Running `terraform apply` in staging shows plan output but resources aren't created
- Workspace has 0 resources in state

**Root Causes:**
1. Running `terraform plan` instead of `terraform apply`
2. Not typing `yes` when prompted to confirm
3. Workspace is empty (expected - first deployment)

**Solution:**
```bash
# Make sure you run APPLY, not PLAN
terraform workspace select staging
terraform apply  # Not 'terraform plan'!

# When prompted, type 'yes' (not just Enter)
# Plan: 47 to add, 0 to change, 0 to destroy.
# Do you want to perform these actions?
#   Enter a value: yes  ← Type this!
```

**Expected Behavior:**
- **Staging (empty)**: `terraform apply` creates ~47 resources (VPC, RDS, EC2, ALB, etc.)
- **Prod (has resources)**: `terraform apply` updates only changed resources

**Verify:**
```bash
# Run diagnostic script
./diagnose-workspace.sh

# Or manually check
terraform workspace select staging
terraform state list  # Should show resources after apply
```

#### Issue: Wrong Workspace Selected

```bash
# Check current workspace
terraform workspace show

# Switch to correct workspace
terraform workspace select dev
```

#### Issue: State File Conflicts

```bash
# Each workspace has its own state
# Ensure you're in the correct workspace before applying
terraform workspace list
terraform workspace select <workspace-name>
```

#### Issue: Password Sync Issues

Password sync is now handled automatically by Terraform using a data source. The password is synced from the RDS-managed secret during `terraform apply`.

**If manual sync is needed:**
```bash
# Run sync script (works with any workspace)
cd ..
./sync-db-password.sh
```

**Check if password is synced:**
```bash
# Verify secret has correct password
aws secretsmanager get-secret-value \
  --secret-id web-app-<workspace>-db-credential \
  --region us-east-1
```

**For more details, see:**
- [PASSWORD_SYNC_TERRAFORM_NATIVE.md](PASSWORD_SYNC_TERRAFORM_NATIVE.md) - Complete password sync documentation
- [DEPLOYMENT_WORKFLOW.md](DEPLOYMENT_WORKFLOW.md) - Deployment workflow details

#### Issue: Resources Created in Wrong Workspace

```bash
# Check which workspace created the resource
terraform state list
terraform show <resource_name>

# Move resource to correct workspace (complex - prefer recreating)
# Or destroy and recreate in correct workspace
```

---

## Summary: Quick Reference

### Workspace Commands

```bash
# List workspaces
terraform workspace list

# Create workspace
terraform workspace new <name>

# Select workspace
terraform workspace select <name>

# Show current workspace
terraform workspace show
```

### Promotion Checklist

- [ ] Changes tested in DEV
- [ ] DEV deployment successful
- [ ] Changes promoted to STAGING
- [ ] STAGING validation passed
- [ ] Changes promoted to PROD
- [ ] PROD deployment successful
- [ ] Post-deployment monitoring completed
- [ ] Changes committed to Git
- [ ] Changes pushed to repository

### Environment Quick Switch

```bash
# Quick workspace switching
alias tf-dev='cd ~/terra/projects/learn-terra/app_db/infrastructure-web-app/terraform && terraform workspace select dev'
alias tf-staging='cd ~/terra/projects/learn-terra/app_db/infrastructure-web-app/terraform && terraform workspace select staging'
alias tf-prod='cd ~/terra/projects/learn-terra/app_db/infrastructure-web-app/terraform && terraform workspace select prod'
```

Add to your `~/.bashrc` or `~/.zshrc` for easy access!

---

## Next Steps

1. ✅ Migrate existing resources to dev workspace
2. ✅ Create staging and prod workspaces
3. ✅ Deploy infrastructure to each environment
4. ✅ Practice promotion workflow
5. ✅ Set up Git repository and commit workflow
6. ✅ Document your process for recruiters

Good luck with your showcase! 🚀
