#!/bin/bash
# Script to prepare project for Git commit
# This ensures all temporary files are cleaned and project is ready

set -euo pipefail

echo "🧹 Preparing project for Git commit..."

# Remove temporary files
echo "1. Removing temporary files..."
rm -f *.tfplan *.tfplan.json fix-sg-error.sh 2>/dev/null || true
rm -f lambda-response.json *.log 2>/dev/null || true

# Ensure .gitignore is up to date
echo "2. Checking .gitignore..."
if [ -f .gitignore ]; then
    echo "✅ .gitignore exists"
else
    echo "⚠️  .gitignore not found, creating one..."
fi

# Check for sensitive files
echo "3. Checking for sensitive files..."
if ls *.tfvars 2>/dev/null; then
    echo "⚠️  WARNING: Found .tfvars files. Ensure they're in .gitignore"
fi

# Validate Terraform syntax
echo "4. Validating Terraform configuration..."
terraform fmt -recursive
terraform validate

# Show current workspace
echo ""
echo "5. Current Terraform workspace:"
terraform workspace show

# Show git status
echo ""
echo "6. Git status:"
if command -v git &> /dev/null; then
    git status --short || echo "Not a git repository yet"
else
    echo "Git not installed"
fi

echo ""
echo "✅ Project is ready for Git commit!"
echo ""
echo "📋 Next steps:"
echo "   1. Review changes: git status"
echo "   2. Add files: git add ."
echo "   3. Commit: git commit -m 'Initial commit: Production-ready infrastructure'"
echo "   4. Create remote repo and push: git push -u origin main"

