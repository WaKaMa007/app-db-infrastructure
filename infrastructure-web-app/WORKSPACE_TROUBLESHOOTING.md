# Workspace Troubleshooting Guide

## Issue: Staging Only Shows Changes, Prod Actually Provisions

### Problem Description

When running `terraform apply` in the **staging** workspace, you see the plan output (changes) but resources aren't actually being created. However, in the **prod** workspace, `terraform apply` successfully creates/provisions all resources in AWS.

### Root Cause

This typically happens when:

1. **Staging workspace hasn't been initialized** - The `.terraform` directory or provider plugins might not be set up
2. **State file location issue** - Terraform might not be finding or creating the state file correctly
3. **You're running `terraform plan` instead of `terraform apply`** - Easy mistake to make
4. **Workspace was created but never had `terraform apply` run** - Empty state means nothing exists

### Diagnosis

Check your workspace state:

```bash
cd infrastructure-web-app/terraform

# Check current workspace
terraform workspace show

# Check if state exists
terraform workspace select staging
terraform state list

# Check if initialized
ls -la .terraform/
```

### Solution Steps

#### Step 1: Ensure Proper Initialization

```bash
cd infrastructure-web-app/terraform

# Select staging workspace
terraform workspace select staging

# Initialize (if not already done)
terraform init

# Verify initialization
terraform version
```

#### Step 2: Run Apply (Not Plan)

Make sure you're running `terraform apply`, not `terraform plan`:

```bash
# ❌ This only shows changes (doesn't create resources)
terraform plan

# ✅ This actually creates resources
terraform apply

# Or use auto-approve for non-interactive
terraform apply -auto-approve
```

#### Step 3: Verify Resources Are Being Created

```bash
# Watch the output - you should see:
# Plan: X to add, Y to change, Z to destroy.
# 
# Do you want to perform these actions?
#   Terraform will perform the actions described above.
#   Only 'yes' will be accepted to approve.
#
# Type: yes

# After apply completes, verify:
terraform state list

# Should show many resources like:
# module.vpc.aws_vpc.this[0]
# module.database.aws_db_instance.this[0]
# aws_autoscaling_group.app-server-asg
# etc.
```

#### Step 4: Check AWS Console

After running `terraform apply`, check AWS Console:
- VPC: Should see `web-app-staging-vpc`
- RDS: Should see `web-app-staging-db-db`
- EC2: Should see instances in `web-app-staging-asg`
- ALB: Should see `web-app-staging-alb`

### Common Mistakes

#### Mistake 1: Running Plan Instead of Apply

```bash
# ❌ Wrong - only shows what would happen
terraform plan

# ✅ Correct - actually does it
terraform apply
```

#### Mistake 2: Not Confirming Apply

```bash
# When you run terraform apply, you need to type 'yes'
terraform apply

# Output:
# Plan: 47 to add, 0 to change, 0 to destroy.
# 
# Do you want to perform these actions?
#   Terraform will perform the actions described above.
#   Only 'yes' will be accepted to approve.
#
#   Enter a value: yes  ← You must type this!
```

#### Mistake 3: Not Initialized

```bash
# If you see "Error: Could not load plugin" or similar
terraform init

# Re-initialize if workspace was just created
terraform init -reconfigure
```

### Expected Behavior

#### Staging Workspace (Empty State)

```bash
terraform workspace select staging
terraform apply

# Expected output:
# Plan: 47 to add, 0 to change, 0 to destroy.
# 
# Do you want to perform these actions?
#   Terraform will perform the actions described above.
#   Only 'yes' will be accepted to approve.
#
#   Enter a value: yes
#
# module.vpc.aws_vpc.this[0]: Creating...
# module.vpc.aws_vpc.this[0]: Creation complete after 5s
# ...
# Apply complete! Resources: 47 added, 0 changed, 0 destroyed.
```

#### Prod Workspace (Resources Exist)

```bash
terraform workspace select prod
terraform apply

# Expected output:
# No changes. Your infrastructure matches the configuration.
#
# This means that Terraform did not detect any differences between your
# configuration and real physical resources that exist.
```

OR if you made changes:

```bash
# Plan: 0 to add, 3 to change, 0 to destroy.
# Apply complete! Resources: 0 added, 3 changed, 0 destroyed.
```

### Verification Commands

After applying in staging, verify resources were created:

```bash
# 1. Check Terraform state
terraform state list | wc -l  # Should be > 0

# 2. Check AWS resources
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=web-app-staging*" --query 'Vpcs[*].VpcId' --output text

aws rds describe-db-instances --db-instance-identifier web-app-staging-db-db --query 'DBInstances[0].DBInstanceStatus' --output text

aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names web-app-staging-asg --query 'AutoScalingGroups[0].DesiredCapacity' --output text
```

### Complete Staging Setup

If staging is completely empty, here's the full setup:

```bash
cd infrastructure-web-app/terraform

# 1. Select workspace
terraform workspace select staging

# 2. Initialize (if needed)
terraform init

# 3. Plan to see what will be created
terraform plan

# 4. Apply to create resources
terraform apply
# Type 'yes' when prompted

# 5. Verify
terraform state list
terraform output
```

### If Issues Persist

1. **Check Terraform logs:**
   ```bash
   export TF_LOG=DEBUG
   terraform apply 2>&1 | tee terraform-debug.log
   ```

2. **Check AWS permissions:**
   ```bash
   aws sts get-caller-identity
   ```

3. **Verify workspace state location:**
   ```bash
   terraform workspace show
   # Should show: staging
   
   ls -la terraform.tfstate.d/staging/ 2>/dev/null
   ```

4. **Re-initialize if corrupted:**
   ```bash
   rm -rf .terraform
   terraform init
   ```

### Summary

**The key difference:**
- **Staging (empty)**: `terraform apply` should CREATE all resources (47+ resources)
- **Prod (has resources)**: `terraform apply` should UPDATE existing resources or show "No changes"

If staging isn't creating resources, you're likely:
1. Running `terraform plan` instead of `terraform apply`
2. Not typing `yes` to confirm
3. Not initialized (`terraform init` needed)
4. Encountering an error (check output)

---

**Next Steps:**
1. Run `terraform workspace select staging`
2. Run `terraform init` (if needed)
3. Run `terraform apply` (not plan!)
4. Type `yes` when prompted
5. Verify with `terraform state list`

