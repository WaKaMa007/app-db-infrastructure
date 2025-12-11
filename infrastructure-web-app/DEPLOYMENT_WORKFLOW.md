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

## Automated Solution (Recommended)

I've updated your Terraform configuration to **automatically sync the password** after RDS is created/updated. The `null_resource.sync_db_password` will:

- Run automatically after `terraform apply`
- Only trigger when RDS instance changes
- Update the secret silently (non-interactive mode)
- Continue even if sync fails (password might already be correct)

### How It Works

```hcl
resource "null_resource" "sync_db_password" {
  triggers = {
    db_instance_id     = module.database.db_instance_identifier
    db_instance_status = module.database.db_instance_status
    # ... other triggers
  }

  provisioner "local-exec" {
    command = "./sync-db-password.sh --auto"
    # Runs automatically after RDS is ready
  }
}
```

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

- **Automated**: Terraform now syncs passwords automatically ✅
- **One-time per workspace**: Only needed when creating new RDS instances
- **No manual steps**: Regular deployments don't require sync
- **Fallback available**: Manual sync script if automation fails

You should **NOT** need to run the sync script manually for regular deployments. It's only needed:
- When setting up a new workspace/environment
- If the automatic sync fails (rare)
- If RDS password is manually rotated

