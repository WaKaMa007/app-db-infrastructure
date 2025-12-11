# Password Sync Issue Fix

## Problem

When deploying to a new workspace (like `prod`), the database password sync isn't working automatically. The RDS instance is created with `manage_master_user_password = true`, but the custom secret in Secrets Manager doesn't get the password automatically.

### Root Cause

**Race Condition**: When RDS creates a database with `manage_master_user_password = true`, AWS creates a managed secret **asynchronously**. The Terraform `null_resource` that runs the sync script executes immediately after RDS reports as "available", but the RDS-managed secret might not be ready yet.

1. RDS instance is created → Status becomes "available"
2. Terraform thinks database is ready → Triggers sync script
3. Sync script tries to read RDS-managed secret → **Secret not ready yet!**
4. Sync fails silently (because of `on_failure = continue`)

## Solution Implemented

### 1. Added `--wait` Flag to Sync Script

The sync script now waits for the RDS-managed secret to be available before trying to sync:

```bash
./sync-db-password.sh --auto --wait
```

**Features:**
- Waits up to 5 minutes (30 retries × 10 seconds) for the secret
- Checks both secret existence AND ability to read the value
- Continues with sync once secret is available

### 2. Updated `null_resource` Triggers

The `null_resource.sync_db_password` now:
- Triggers on `db_instance_master_user_secret_arn` changes (tracks when secret is created)
- Uses `--wait` flag in the sync script
- Better error handling

### 3. Better Dependency Chain

```
RDS Database → RDS-Managed Secret Created → Custom Secret Created → Sync Script Runs (with --wait)
```

## How It Works Now

### Automatic Sync (During `terraform apply`)

1. **RDS is created** with `manage_master_user_password = true`
2. **Terraform waits** for RDS to be available
3. **RDS-managed secret is created** (asynchronously by AWS)
4. **Custom secret is created** with initial password from `var.db_password`
5. **Sync script runs** with `--wait` flag:
   - Waits for RDS-managed secret to be available
   - Reads password from RDS-managed secret
   - Updates custom secret with correct password
6. **Application can connect** ✅

### Manual Sync (If Needed)

If automatic sync fails or you need to sync manually:

```bash
cd infrastructure-web-app
./sync-db-password.sh
```

This will:
- Detect current workspace
- Find RDS instance
- Wait for secret if needed
- Sync password automatically

## Verification

After `terraform apply`, check if sync worked:

```bash
# Check if secrets are in sync
cd infrastructure-web-app
./sync-db-password.sh

# Or check directly
terraform workspace select prod
terraform output -raw db_instance_id
aws secretsmanager get-secret-value --secret-id web-app-prod-db-credential --region us-east-1
```

## Troubleshooting

### If Password Sync Still Fails

1. **Wait a few minutes** - RDS secrets can take 2-5 minutes to be fully available
2. **Run sync manually:**
   ```bash
   cd infrastructure-web-app
   ./sync-db-password.sh
   ```
3. **Check RDS console:**
   - Go to RDS → Your database → Configuration
   - Look for "Master user secret" - should show an ARN
4. **Check Secrets Manager:**
   - Should see two secrets:
     - `rds!db-xxxxx-xxxxx` (RDS-managed)
     - `web-app-{workspace}-db-credential` (Your custom secret)

### Common Issues

**Issue:** "Secret not found"
- **Fix:** Wait 2-5 minutes and run sync again
- **Check:** RDS console to see if secret ARN is populated

**Issue:** "Password authentication failed"
- **Fix:** Run `./sync-db-password.sh` manually
- **Check:** Both secrets exist and have same password

**Issue:** Sync script runs but doesn't update
- **Fix:** Check IAM permissions for Secrets Manager
- **Fix:** Verify workspace is correct (`terraform workspace show`)

## Why Not Use RDS-Managed Secret Directly?

You might wonder: "Why not just use the RDS-managed secret directly?"

**Reasons:**
1. **Format**: RDS-managed secret has a different JSON structure than what our app expects
2. **Naming**: RDS secret names are auto-generated (`rds!db-xxxxx`)
3. **Control**: Custom secret allows us to control the exact format and include additional metadata
4. **Consistency**: Our application code expects a specific secret structure

## Best Practices

1. **Always wait for sync** after first deployment
2. **Run manual sync** if you see connection errors
3. **Check logs** if sync fails (the script provides detailed output)
4. **Use `--wait` flag** in Terraform (automatically done now)

## Summary

✅ **Fixed**: Added `--wait` flag to sync script  
✅ **Fixed**: Updated null_resource to track secret ARN  
✅ **Improved**: Better error handling and retry logic  
✅ **Result**: Password sync now works automatically, even on first deployment

---

**Note**: If you're still having issues after this fix, run `./sync-db-password.sh` manually. It will diagnose and fix the issue.

