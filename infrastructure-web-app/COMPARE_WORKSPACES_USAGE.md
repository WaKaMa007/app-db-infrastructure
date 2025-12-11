# compare-workspaces.sh - Usage Guide

## Works with ANY Workspace Names! ✅

The script has been updated to work with **any workspace names**, not just `dev`, `staging`, and `prod`.

## What Works Out of the Box

### ✅ Core Functionality (No Changes Needed)

All of these work with **any workspace names**:

1. **Workspace comparison** - Compare any two workspaces
2. **Resource counting** - Count resources in any workspace
3. **State comparison** - Compare what resources exist
4. **Plan summaries** - Show terraform plan for any workspace
5. **Output comparisons** - Compare terraform outputs
6. **Configuration diff** - Show configuration differences

### Usage Examples

```bash
# Compare any two workspaces
./compare-workspaces.sh dev prod          # Works ✅
./compare-workspaces.sh staging prod      # Works ✅
./compare-workspaces.sh qa production     # Works ✅ (new names!)
./compare-workspaces.sh test integration  # Works ✅ (any names!)
./compare-workspaces.sh                   # Uses defaults (dev vs staging)
```

## What Was Hardcoded (Now Fixed!)

### Before
- ❌ Only showed configuration details for `dev`, `staging`, `prod`
- ❌ Filtered workspace list to only show those three
- ❌ Had hardcoded default values

### After
- ✅ Works with **any workspace names**
- ✅ Tries to read configuration from `workspaces.tf` if it exists
- ✅ Falls back gracefully for unknown workspace names
- ✅ Shows helpful messages for custom workspace names

## How It Handles Different Workspace Names

### For Known Workspaces (dev, staging, prod)

If your workspace is named `dev`, `staging`, or `prod`, the script will:
1. Try to read actual config from `workspaces.tf`
2. Show expected configuration values
3. Display common configuration patterns

### For Custom Workspace Names

If you use custom names like `qa`, `test`, `integration`, `production`, etc.:
1. ✅ All comparison features work perfectly
2. ✅ Shows actual configuration from terraform state
3. ✅ Shows configuration from `terraform show`
4. ⚠️  Won't show "expected" values (since they're not pre-defined)
5. ✅ Still shows all other useful comparisons

## Example: Custom Workspace Names

```bash
# Create custom workspaces
terraform workspace new qa
terraform workspace new integration
terraform workspace new production

# Compare them - works perfectly!
./compare-workspaces.sh qa integration
./compare-workspaces.sh qa production
```

**Output will show:**
- ✅ Resource counts
- ✅ State differences
- ✅ Plan summaries
- ✅ Output comparisons
- ✅ Configuration differences (from actual terraform state)
- ⚠️  Won't show "expected values" section (since they're custom names)

## Configuration Detection

The script tries to detect configuration in this order:

1. **From `workspaces.tf`** - If your workspace matches a config in `workspaces.tf`
2. **From Terraform State** - Shows actual deployed configuration
3. **From Terraform Plan** - Shows what would be deployed
4. **Fallback** - Shows generic message

## Best Practices

### For Standard Environments (dev/staging/prod)

Use the standard names - the script provides the best experience:
```bash
./compare-workspaces.sh dev staging
./compare-workspaces.sh staging prod
```

### For Custom Environments

The script works, but you might want to:

1. **Add to `workspaces.tf`** - Define your custom workspace configs there:
   ```hcl
   workspace_config = {
     qa = {
       instance_type = "t3.small"
       # ... etc
     }
   }
   ```

2. **Or just use as-is** - The script will still show:
   - Actual deployed configuration
   - Resource differences
   - Plan summaries
   - Output comparisons

## What You Need to Change (Nothing!)

✅ **The script works with any workspace names out of the box!**

The only thing that might be different:
- For custom workspace names, the "Expected Configuration" section won't show predefined values
- Everything else (comparisons, diffs, plans) works exactly the same

## Testing with Custom Workspaces

```bash
# Test with any workspace names
terraform workspace new my-custom-env
terraform workspace new another-env

# Compare them
./compare-workspaces.sh my-custom-env another-env

# Should work perfectly! ✅
```

## Summary

| Feature | Works with Custom Names? |
|---------|-------------------------|
| Compare any two workspaces | ✅ Yes |
| Resource counting | ✅ Yes |
| State comparison | ✅ Yes |
| Plan summaries | ✅ Yes |
| Output comparison | ✅ Yes |
| Configuration diff | ✅ Yes |
| Expected values display | ⚠️ Only for dev/staging/prod (unless in workspaces.tf) |

**Bottom line:** You can use this script with **any workspace names** without any modifications! 🎉

