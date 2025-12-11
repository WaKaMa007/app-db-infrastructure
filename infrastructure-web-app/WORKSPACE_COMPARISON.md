# Workspace Comparison Tools

## Overview

When working with multiple Terraform workspaces (dev, staging, prod), it's important to be able to compare configurations and understand differences between environments. This guide provides several tools and methods for comparing workspaces in a human-readable format.

## Tools Available

### 1. `compare-workspaces.sh` - Comprehensive Comparison Tool

**Best for:** Detailed analysis and full workspace comparison

**Usage:**
```bash
cd infrastructure-web-app
./compare-workspaces.sh [workspace1] [workspace2]
```

**Examples:**
```bash
# Compare dev and staging (default)
./compare-workspaces.sh

# Compare dev and prod
./compare-workspaces.sh dev prod

# Compare staging and prod
./compare-workspaces.sh staging prod
```

**What it shows:**
- ✅ Workspace overview (resource counts, outputs)
- ✅ Configuration differences (instance types, scaling, etc.)
- ✅ Resource comparison (what exists in each workspace)
- ✅ Side-by-side comparison of outputs
- ✅ Plan summaries for each workspace
- ✅ Expected configuration values from `workspaces.tf`

**Output Format:**
- Color-coded, easy to read
- Sectioned with clear headers
- Highlights differences

### 2. `workspace-diff.sh` - Quick Comparison Tool

**Best for:** Quick checks and simple comparisons

**Usage:**
```bash
cd infrastructure-web-app
./workspace-diff.sh <workspace1> <workspace2>
```

**Examples:**
```bash
./workspace-diff.sh dev staging
./workspace-diff.sh dev prod
```

**What it shows:**
- Plan summaries
- Output comparisons

**Output Format:**
- Simple, concise
- Quick to scan
- Less detailed than `compare-workspaces.sh`

## Alternative Methods

### Method 1: Terraform Plan Comparison

Generate plans for each workspace and compare:

```bash
cd infrastructure-web-app/terraform

# Generate plans
terraform workspace select dev
terraform plan -out=dev.tfplan
terraform plan -no-color > dev-plan.txt

terraform workspace select prod
terraform plan -out=prod.tfplan
terraform plan -no-color > prod-plan.txt

# Compare plans (requires same resources to be meaningful)
diff -u dev-plan.txt prod-plan.txt | less
```

**Pros:**
- Shows actual differences Terraform will make
- Works with Terraform's native commands

**Cons:**
- Less readable than formatted tools
- Hard to compare different resource counts

### Method 2: Terraform Output Comparison

Compare outputs between workspaces:

```bash
cd infrastructure-web-app/terraform

# Get outputs as JSON for easier comparison
terraform workspace select dev
terraform output -json > dev-outputs.json

terraform workspace select prod
terraform output -json > prod-outputs.json

# Use jq to format comparison (if installed)
jq -S . dev-outputs.json > dev-outputs-sorted.json
jq -S . prod-outputs.json > prod-outputs-sorted.json
diff -u dev-outputs-sorted.json prod-outputs-sorted.json
```

**Pros:**
- Shows deployed infrastructure values
- JSON is machine-readable

**Cons:**
- Requires resources to be deployed
- Less human-readable

### Method 3: State List Comparison

Compare what resources exist in each workspace:

```bash
cd infrastructure-web-app/terraform

terraform workspace select dev
terraform state list | sort > dev-resources.txt

terraform workspace select prod
terraform state list | sort > prod-resources.txt

# Show differences
comm -23 dev-resources.txt prod-resources.txt  # Only in dev
comm -13 dev-resources.txt prod-resources.txt  # Only in prod
comm -12 dev-resources.txt prod-resources.txt  # In both
```

**Pros:**
- Quick to see what's deployed
- Easy to spot missing resources

**Cons:**
- Doesn't show configuration differences
- Doesn't show resource values

### Method 4: Using Terraform Show

Compare current state of resources:

```bash
cd infrastructure-web-app/terraform

terraform workspace select dev
terraform show -json | jq '.values.root_module.resources[] | select(.type == "aws_autoscaling_group") | .values' > dev-asg.json

terraform workspace select prod
terraform show -json | jq '.values.root_module.resources[] | select(.type == "aws_autoscaling_group") | .values' > prod-asg.json

# Compare specific resource types
diff -u <(jq -S . dev-asg.json) <(jq -S . prod-asg.json)
```

**Pros:**
- Shows actual deployed configuration
- Can filter by resource type

**Cons:**
- Requires resources to exist
- Requires `jq` for JSON parsing

## Recommended Workflow

### Daily Use
```bash
# Quick check before promoting changes
./workspace-diff.sh dev staging
```

### Before Major Deployments
```bash
# Comprehensive comparison
./compare-workspaces.sh dev prod
```

### When Troubleshooting
```bash
# Compare what's actually deployed
terraform workspace select dev
terraform state list > /tmp/dev-resources.txt

terraform workspace select prod
terraform state list > /tmp/prod-resources.txt

diff /tmp/dev-resources.txt /tmp/prod-resources.txt
```

## Understanding the Output

### Configuration Differences

When comparing workspaces, look for:

1. **Instance Types:**
   - Dev: `t3.micro`
   - Staging: `t3.small`
   - Prod: `t3.medium`

2. **Scaling Configuration:**
   - Dev: Min: 1, Max: 2, Desired: 1
   - Staging: Min: 1, Max: 3, Desired: 2
   - Prod: Min: 2, Max: 5, Desired: 2

3. **Database:**
   - Dev: `db.t3.micro`
   - Staging: `db.t3.small`
   - Prod: `db.t3.medium`

4. **Deletion Protection:**
   - Dev/Staging: ❌ Disabled
   - Prod: ✅ Enabled

### Resource Count Differences

- **Normal:** Different workspaces may have different resource counts
- **Expected:** Prod typically has more resources (higher availability)
- **Warning:** If a workspace shows "0 resources", it hasn't been deployed yet

### Plan Summary Differences

- **"No changes"**: Workspace matches configuration
- **"X to add"**: New resources will be created
- **"X to change"**: Existing resources will be updated
- **"X to destroy"**: Resources will be removed

## Tips

1. **Always run plan first:**
   ```bash
   terraform workspace select <workspace>
   terraform plan
   ```

2. **Use the comparison tools before promoting:**
   ```bash
   ./compare-workspaces.sh dev staging
   # Review differences
   # Promote if acceptable
   ```

3. **Save comparison output:**
   ```bash
   ./compare-workspaces.sh dev prod > comparison-report.txt
   ```

4. **Compare specific resource types:**
   ```bash
   terraform workspace select dev
   terraform state list | grep "aws_autoscaling_group"
   
   terraform workspace select prod
   terraform state list | grep "aws_autoscaling_group"
   ```

## Troubleshooting

### "Workspace does not exist" error
- Make sure workspaces are created: `terraform workspace list`
- Create missing workspace: `terraform workspace new <name>`

### "No resources in state" message
- Workspace hasn't been deployed yet
- Run `terraform apply` in that workspace first

### "Plan not available" message
- Terraform might have errors
- Check with: `terraform validate`
- Review plan output manually: `terraform plan`

## Example Output

```
════════════════════════════════════════════════════════════════
Comparing: dev vs prod
════════════════════════════════════════════════════════════════

Plan Summary:
dev: Plan: 0 to add, 0 to change, 0 to destroy.
prod: Plan: 2 to add, 1 to change, 0 to destroy.

Outputs Comparison:

━━━ dev ━━━
Workspace: dev
alb_https_url = "https://dev.211125336427.realhandsonlabs.net"
db_instance_id = "web-app-dev-db-db"
instance_count = 1

━━━ prod ━━━
Workspace: prod
alb_https_url = "https://prod.211125336427.realhandsonlabs.net"
db_instance_id = "web-app-prod-db-db"
instance_count = 2
```

---

**Quick Reference:**
- `./compare-workspaces.sh` - Full detailed comparison
- `./workspace-diff.sh` - Quick simple comparison
- `terraform plan` - See what will change
- `terraform state list` - See what's deployed
- `terraform output` - See output values

