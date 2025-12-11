# Git Setup Guide

## Pre-Commit Checklist

✅ **Before committing to Git:**

1. **Remove sensitive data:**
   - No `.tfvars` files with real passwords
   - No hardcoded credentials
   - All secrets in Secrets Manager

2. **Clean temporary files:**
   ```bash
   ./prepare-for-git.sh
   ```

3. **Validate Terraform:**
   ```bash
   terraform fmt -recursive
   terraform validate
   ```

4. **Workspace Selection (Optional but Recommended):**
   ```bash
   # You CAN commit from any workspace, but recommended:
   # - Commit feature work from dev workspace
   # - Commit production deployments from prod workspace
   terraform workspace show  # Check current workspace
   ```

**Note:** Git doesn't care which Terraform workspace is active - it tracks files. 
The workspace only affects which Terraform state file you're using. However, 
switching to prod before committing ensures you're committing production-ready code.

## Git Workflow

### Initial Setup

```bash
# 1. Prepare project
./prepare-for-git.sh

# 2. Initialize Git (if not already)
git init

# 3. Add all files
git add .

# 4. Create initial commit
git commit -m "Initial commit: Production-ready infrastructure with workspace support"

# 5. Create remote repository (GitHub/GitLab/etc)
# Then add remote:
git remote add origin <your-repo-url>

# 6. Push to main branch
git branch -M main
git push -u origin main
```

### Daily Workflow

```bash
# Work on feature in dev workspace
terraform workspace select dev
# ... make changes ...
terraform plan
terraform apply

# Commit changes
git add .
git commit -m "feat: Add CloudWatch monitoring"

# Push to remote
git push origin main
```

### Environment-Specific Commits

```bash
# Work in dev
terraform workspace select dev
terraform apply

# Test in staging
terraform workspace select staging
terraform apply

# Deploy to prod (from main branch)
terraform workspace select prod
terraform apply
git add .
git commit -m "chore: Deploy to production"
git push origin main
```

## Branch Strategy (Recommended)

```
main          → Production deployments only
├── staging   → Staging environment
└── develop   → Development work
```

### Feature Branch Workflow

```bash
# Create feature branch
git checkout -b feature/cloudwatch-monitoring

# Work on feature
# ... make changes ...

# Commit and push
git add .
git commit -m "feat: Add CloudWatch alarms and dashboard"
git push origin feature/cloudwatch-monitoring

# Create Pull Request
# After review, merge to develop → staging → main
```

## Important Notes

1. **Never commit:**
   - `.tfstate` files (use remote backend)
   - `.tfvars` files with real values
   - Passwords or API keys
   - Temporary scripts or test files

2. **Always commit:**
   - Terraform configuration files (`.tf`)
   - Documentation (`.md`)
   - Helper scripts (`.sh`)
   - `.gitignore` updates

3. **Workspace State:**
   - Each workspace maintains separate state
   - State files stored in remote backend (S3)
   - Workspace selection affects which state you're working with

