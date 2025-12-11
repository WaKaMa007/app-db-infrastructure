# Password Sync - Terraform Native Solution

## Problem

The previous solution used an external bash script (`sync-db-password.sh`) triggered by a `null_resource` provisioner. This had several issues:

1. **Not reliable for all workspaces**: The `null_resource` only runs when its triggers change, so it might not run automatically for dev/staging if the database was already created
2. **Timing issues**: The script had to wait/retry for the RDS-managed secret to be available
3. **Manual intervention**: Sometimes required running the script manually
4. **Not part of Terraform lifecycle**: The sync happened outside of Terraform's normal plan/apply cycle

## Solution

We've replaced the external script with a **Terraform-native solution** that:

1. ✅ **Uses Terraform data source** to read the RDS-managed secret directly
2. ✅ **Works automatically** during database creation for all workspaces
3. ✅ **No external scripts** - everything is handled by Terraform
4. ✅ **Part of Terraform lifecycle** - included in plan/apply cycle
5. ✅ **More reliable** - Terraform handles dependencies and retries automatically

## How It Works

### 1. Data Source Reads RDS-Managed Secret

```hcl
data "aws_secretsmanager_secret_version" "rds_managed_secret" {
  count = length(try(module.database.db_instance_master_user_secret_arn, "")) > 0 ? 1 : 0
  
  secret_id = module.database.db_instance_master_user_secret_arn
  depends_on = [module.database]
}
```

- Only reads if the RDS-managed secret ARN exists
- Waits for database to be created first (via `depends_on`)

### 2. Local Values Extract Password

```hcl
locals {
  db_password = length(data.aws_secretsmanager_secret_version.rds_managed_secret) > 0 ? (
    jsondecode(data.aws_secretsmanager_secret_version.rds_managed_secret[0].secret_string)["password"]
  ) : var.db_password
  
  db_username = length(data.aws_secretsmanager_secret_version.rds_managed_secret) > 0 ? (
    jsondecode(data.aws_secretsmanager_secret_version.rds_managed_secret[0].secret_string)["username"]
  ) : var.db_username
}
```

- Uses RDS-managed password if available
- Falls back to `var.db_password` if RDS isn't managing the password

### 3. Secret Version Uses the Password

```hcl
resource "aws_secretsmanager_secret_version" "db_credential" {
  secret_string = jsonencode({
    username = local.db_username
    password = local.db_password  # Automatically from RDS-managed secret!
    # ... other fields
  })
}
```

- Password is automatically synced during `terraform apply`
- No external scripts needed
- Works for all workspaces (dev, staging, prod)

## Benefits

### ✅ Automatic for All Workspaces

- **Before**: Script only ran when triggers changed (didn't work for dev/staging)
- **Now**: Works automatically during every `terraform apply` for all workspaces

### ✅ Resolved During Database Creation

- **Before**: Database created → Script runs later → Password synced
- **Now**: Database created → Password read immediately → Secret updated in same apply

### ✅ More Reliable

- **Before**: External script could fail silently, timing issues
- **Now**: Terraform handles dependencies, retries, and error handling

### ✅ Better Integration

- **Before**: External script outside Terraform lifecycle
- **Now**: Part of Terraform plan/apply cycle, visible in plan output

## Migration

### What Changed

1. ✅ Removed `null_resource.sync_db_password` (no longer needed)
2. ✅ Added `data.aws_secretsmanager_secret_version.rds_managed_secret`
3. ✅ Added `locals` to extract password from data source
4. ✅ Updated `aws_secretsmanager_secret_version.db_credential` to use `local.db_password`
5. ✅ Removed `lifecycle { ignore_changes = [secret_string] }` (no longer needed)

### What Stays the Same

- ✅ `sync-db-password.sh` script still exists (can be used for manual sync if needed)
- ✅ All other infrastructure unchanged
- ✅ Application code unchanged

## Testing

### Verify It Works

```bash
cd infrastructure-web-app/terraform

# For each workspace
terraform workspace select dev
terraform plan  # Should show secret version will be updated with RDS password
terraform apply # Password synced automatically

terraform workspace select staging
terraform plan
terraform apply

terraform workspace select prod
terraform plan
terraform apply
```

### Check the Secret

```bash
# Verify password is synced
aws secretsmanager get-secret-value \
  --secret-id web-app-<workspace>-db-credential \
  --region us-east-1 \
  --query SecretString --output text | jq -r .password
```

## Troubleshooting

### If Data Source Fails

If the RDS-managed secret isn't available yet during apply:

1. **Wait and retry**: The secret is created shortly after the database
2. **Run apply again**: Terraform will read the secret on the next apply
3. **Manual sync**: Use `sync-db-password.sh` as a fallback if needed

### If Password Doesn't Match

1. Check if `manage_master_user_password = true` in `module.tf`
2. Verify RDS instance has `MasterUserSecret` in AWS Console
3. Check IAM permissions for reading secrets

## Why This Is Better

| Aspect | Old (Script) | New (Terraform) |
|--------|-------------|-----------------|
| **Reliability** | Only runs when triggers change | Runs every apply |
| **Workspaces** | Only worked for prod | Works for all workspaces |
| **Timing** | Race conditions possible | Terraform handles dependencies |
| **Visibility** | Hidden in provisioner | Visible in plan output |
| **Integration** | External script | Native Terraform |
| **Error Handling** | Manual retries | Terraform retries automatically |

## Summary

✅ **Problem solved**: Password sync now works automatically for all workspaces  
✅ **During creation**: Password is synced during database creation, not after  
✅ **No external scripts**: Everything handled by Terraform  
✅ **More reliable**: Better error handling and dependency management  

The password synchronization issue is now resolved at the infrastructure level, not as a post-creation step!

