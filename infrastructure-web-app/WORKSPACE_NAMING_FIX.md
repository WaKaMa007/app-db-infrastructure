# Workspace Naming Conflict Fix

## Problem

When deploying to the **prod** workspace, Terraform was trying to **create** resources that already existed, instead of **updating** existing ones. This happened because several resources had hardcoded `"dev"` values or non-workspace-specific names.

### Errors Encountered

```
Error: Route53 Record already exists: dev.211125336427.realhandsonlabs.net
Error: IAM Role already exists: ssm-role
Error: DB Subnet Group already exists: dev-vpc
Error: SSL Certificate validation record already exists
```

## Root Cause

Resources were created in the **dev** workspace (or default workspace with dev naming) with hardcoded names. When switching to **prod** workspace:

1. Terraform state in prod was empty/fresh
2. Terraform tried to create resources
3. AWS rejected because resources with those names already existed
4. This happened because names weren't workspace-specific

## Files Fixed

### 1. `route53.tf`
**Before:**
```hcl
name = "dev.${var.hosted_zone_name}"
```

**After:**
```hcl
name = "${local.workspace_env}.${var.hosted_zone_name}"
```

**Result:** Route53 records are now workspace-specific:
- Dev: `dev.211125336427.realhandsonlabs.net`
- Staging: `staging.211125336427.realhandsonlabs.net`
- Prod: `prod.211125336427.realhandsonlabs.net`

### 2. `ssl_cert.tf`
**Before:**
```hcl
domain_name = "dev.${var.hosted_zone_name}"
```

**After:**
```hcl
domain_name = "${local.workspace_env}.${var.hosted_zone_name}"
```

**Result:** SSL certificates are now workspace-specific

### 3. `ssm.tf`
**Before:**
```hcl
name = "ssm-role"
name = "ssm-instance-profile"
```

**After:**
```hcl
name = "${local.name_prefix}-ssm-role"
name = "${local.name_prefix}-ssm-instance-profile"
```

**Result:** IAM roles are now workspace-specific:
- Dev: `web-app-dev-ssm-role`
- Staging: `web-app-staging-ssm-role`
- Prod: `web-app-prod-ssm-role`

### 4. `module.tf` (VPC)
**Before:**
```hcl
name = var.vpc_name  # Default was "dev-vpc"
```

**After:**
```hcl
name = var.vpc_name != "" ? var.vpc_name : "${local.name_prefix}-vpc"
```

**Result:** VPC names are now workspace-specific:
- Dev: `web-app-dev-vpc`
- Staging: `web-app-staging-vpc`
- Prod: `web-app-prod-vpc`

## Impact

### ✅ What This Fixes

1. **No More Conflicts**: Each workspace can now have its own resources with unique names
2. **Proper Isolation**: Dev, staging, and prod environments are truly isolated
3. **Correct Behavior**: `terraform apply` in prod will create new resources (not conflict with dev)

### ⚠️ Existing Resources

If you already have resources in AWS created with the old hardcoded names:

#### Option 1: Clean Slate (Recommended for Learning/Showcase)
Destroy existing resources and recreate with new names:

```bash
# Switch to dev workspace (where old resources exist)
terraform workspace select dev

# Destroy old resources
terraform destroy

# Recreate with new naming (if needed)
terraform apply
```

#### Option 2: Import Existing Resources
Import existing resources into the correct workspace state:

```bash
# This is complex and not recommended unless you need to preserve data
# You'd need to import each resource individually
terraform import <resource_type>.<resource_name> <aws_resource_id>
```

#### Option 3: Keep Dev As-Is, Deploy Fresh to Prod
Since dev already works, keep it. Deploy fresh to prod/staging:

```bash
# Prod workspace will now create resources with "prod" in the name
terraform workspace select prod
terraform apply  # Creates: web-app-prod-*, prod.domain, etc.
```

## Next Steps

1. **Review the changes:**
   ```bash
   cd infrastructure-web-app/terraform
   git diff route53.tf ssl_cert.tf ssm.tf module.tf variables.tf
   ```

2. **Test in a workspace:**
   ```bash
   terraform workspace select staging
   terraform plan  # Should show resources with "staging" in names
   ```

3. **Deploy to prod:**
   ```bash
   terraform workspace select prod
   terraform plan  # Should show ~47 resources to create with "prod" names
   terraform apply  # Type 'yes' when prompted
   ```

4. **Verify naming:**
   ```bash
   # Check AWS Console or use AWS CLI
   aws route53 list-resource-record-sets --hosted-zone-id <zone-id> | grep "prod\|staging\|dev"
   aws iam list-roles | grep "ssm-role"
   ```

## Verification Checklist

After applying fixes, verify:

- [ ] Route53 records: `{workspace}.domain` exists for each workspace
- [ ] SSL certificates: `{workspace}.domain` certificates exist
- [ ] IAM roles: `web-app-{workspace}-ssm-role` exists
- [ ] VPC names: `web-app-{workspace}-vpc` exists
- [ ] No naming conflicts when deploying to different workspaces
- [ ] Resources in prod have "prod" in their names
- [ ] Resources in staging have "staging" in their names
- [ ] Resources in dev have "dev" in their names

## Best Practices Applied

✅ **Workspace-based naming**: All resources use `${local.workspace_env}` or `${local.name_prefix}`  
✅ **No hardcoded values**: Environment-specific values come from workspace  
✅ **Isolation**: Each workspace creates its own set of resources  
✅ **Consistency**: All resources follow the same naming pattern

---

**Note:** The `local.name_prefix` and `local.workspace_env` are defined in `locals.tf` and automatically use the Terraform workspace name, ensuring proper isolation between environments.

