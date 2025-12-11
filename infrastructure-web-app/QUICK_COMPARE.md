# Quick Workspace Comparison Guide

## TL;DR - Quick Commands

```bash
cd infrastructure-web-app

# Comprehensive comparison (recommended)
./compare-workspaces.sh dev prod

# Quick comparison
./workspace-diff.sh dev staging

# Manual comparison
terraform workspace select dev && terraform plan
terraform workspace select prod && terraform plan
```

## What Each Tool Does

### `./compare-workspaces.sh` ⭐ Recommended
- **Shows:** Everything (configs, resources, outputs, plans)
- **Format:** Color-coded, sectioned, easy to read
- **Use when:** You need a complete picture
- **Time:** ~30 seconds (runs terraform plan)

### `./workspace-diff.sh`
- **Shows:** Plans and outputs only
- **Format:** Simple, concise
- **Use when:** Quick check before deployment
- **Time:** ~20 seconds

## Common Scenarios

### Before promoting dev → staging
```bash
./workspace-diff.sh dev staging
# Review differences
# If OK: terraform workspace select staging && terraform apply
```

### Before promoting staging → prod
```bash
./compare-workspaces.sh staging prod
# Review all differences carefully
# Check: deletion_protection = true in prod
# If OK: terraform workspace select prod && terraform apply
```

### Debugging workspace issues
```bash
./compare-workspaces.sh dev prod
# Look for:
# - Resource count differences
# - Configuration mismatches
# - Missing resources
```

## Output Interpretation

### ✅ Good Signs
- Different instance types (expected: dev=small, prod=medium)
- Different scaling (expected: dev=less, prod=more)
- Same resource types exist in both
- Plans show "No changes" or minimal changes

### ⚠️ Warning Signs
- Same instance types (should differ)
- Deletion protection disabled in prod (should be enabled)
- Resources missing in one workspace
- Large number of "to add" in prod (might be expected on first deploy)

## Tips

1. **Save comparison for records:**
   ```bash
   ./compare-workspaces.sh dev prod > comparison-$(date +%Y%m%d).txt
   ```

2. **Compare specific resources:**
   ```bash
   terraform workspace select dev
   terraform state show aws_autoscaling_group.app-server-asg
   
   terraform workspace select prod
   terraform state show aws_autoscaling_group.app-server-asg
   ```

3. **Quick resource count check:**
   ```bash
   for ws in dev staging prod; do
     terraform workspace select $ws
     echo "$ws: $(terraform state list 2>/dev/null | wc -l) resources"
   done
   ```

