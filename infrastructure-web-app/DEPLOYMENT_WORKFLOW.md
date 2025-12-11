# Deployment Workflow - Password Sync

## Quick Answer: When Do You Need to Sync?

**Short answer: Only once per workspace, or when RDS password is rotated.**

## Detailed Scenarios

### ✅ **You DON'T need to sync if:**
1. **Updating existing infrastructure** - If you're just updating EC2 instances, ALB, security groups, etc., the password doesn't change
2. **RDS instance already exists** - The password is already synced from the initial deployment
3. **No password changes** - RDS-managed passwords don't change unless manually rotated

### ⚠️ **You DO need to sync if:**
1. **New workspace/environment** - Each workspace (dev, staging, prod) has its own RDS instance
2. **Fresh RDS creation** - When creating a brand new RDS instance with `manage_master_user_password = true`
3. **Password rotation** - If AWS rotates the RDS-managed password (rare, usually manual)
4. **After RDS restore** - If you restore from a snapshot, password might change

## Automated Solution (Terraform-Native)

The Terraform configuration now uses a **data source** to automatically read the RDS-managed password during `terraform apply`. This is more reliable than external scripts and works for all workspaces:

- ✅ Runs automatically during every `terraform apply`
- ✅ Works for all workspaces (dev, staging, prod)
- ✅ Part of Terraform lifecycle (visible in plan output)
- ✅ No external scripts required
- ✅ Resolves password sync during database creation

### How It Works

```hcl
# Data source reads RDS-managed secret
data "aws_secretsmanager_secret_version" "rds_managed_secret" {
  count = length(try(module.database.db_instance_master_user_secret_arn, "")) > 0 ? 1 : 0
  secret_id = module.database.db_instance_master_user_secret_arn
  depends_on = [module.database]
}

# Extract password from RDS secret
locals {
  db_password = length(data.aws_secretsmanager_secret_version.rds_managed_secret) > 0 ? (
    jsondecode(data.aws_secretsmanager_secret_version.rds_managed_secret[0].secret_string)["password"]
  ) : var.db_password
}

# Secret version uses the RDS-managed password automatically
resource "aws_secretsmanager_secret_version" "db_credential" {
  secret_string = jsonencode({
    password = local.db_password  # Automatically from RDS!
    # ... other fields
  })
}
```

See [PASSWORD_SYNC_TERRAFORM_NATIVE.md](PASSWORD_SYNC_TERRAFORM_NATIVE.md) for complete details.

## Manual Sync (If Needed)

If for some reason the automatic sync doesn't work, you can manually run:

```bash
cd infrastructure-web-app
./sync-db-password.sh
```

## Typical Deployment Workflow

### First Time Setup (New Workspace)
```bash
# 1. Create infrastructure
cd infrastructure-web-app/terraform
terraform workspace select dev  # or staging, prod
terraform init
terraform plan
terraform apply

# 2. Password sync happens automatically via null_resource
#    If it fails, run manually:
cd ..
./sync-db-password.sh
```

### Regular Updates
```bash
# Just run terraform apply - password sync is automatic
cd infrastructure-web-app/terraform
terraform plan
terraform apply
# ✅ No manual sync needed!
```

### New Environment
```bash
# Each workspace needs its own sync (one-time)
terraform workspace new staging
terraform apply
# Sync happens automatically, or run manually if needed
```

## Troubleshooting

### If Application Can't Connect to Database

1. **Check if sync ran:**
   ```bash
   ./sync-db-password.sh
   ```

2. **Verify secret has correct password:**
   ```bash
   aws secretsmanager get-secret-value \
     --secret-id web-app-dev-db-credential \
     --region us-east-1
   ```

3. **Check RDS instance status:**
   ```bash
   aws rds describe-db-instances \
     --db-instance-identifier web-app-dev-db-db \
     --region us-east-1
   ```

## Summary

- **Automated**: Password sync happens automatically during `terraform apply` ✅
- **Terraform-native**: Uses data source, no external scripts needed
- **Works for all workspaces**: dev, staging, and prod
- **During creation**: Password is synced when database is created, not after
- **Fallback available**: Manual sync script (`sync-db-password.sh`) if needed

You should **NOT** need to run the sync script manually. The password is automatically synced:
- ✅ During initial database creation
- ✅ On every `terraform apply` (if RDS-managed secret exists)
- ✅ Works for all workspaces automatically

Manual sync script is only needed for:
- Troubleshooting password issues
- After manual password rotation
- If Terraform data source fails (rare)

See [PASSWORD_SYNC_TERRAFORM_NATIVE.md](PASSWORD_SYNC_TERRAFORM_NATIVE.md) for complete documentation.

