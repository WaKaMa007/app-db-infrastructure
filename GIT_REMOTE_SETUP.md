# Setting Up Git Remote

Your repository is initialized locally but doesn't have a remote configured yet.

## Step 1: Create a Remote Repository

### GitHub
1. Go to [GitHub.com](https://github.com) and sign in
2. Click the "+" icon in the top right → "New repository"
3. Repository name: `app-db-infrastructure` (or your preferred name)
4. Description: "Production-ready Terraform infrastructure for Flask web app with PostgreSQL on AWS"
5. Visibility: Choose Public or Private
6. **Don't** initialize with README, .gitignore, or license (you already have these)
7. Click "Create repository"

### GitLab
1. Go to [GitLab.com](https://gitlab.com) and sign in
2. Click "New project" → "Create blank project"
3. Project name: `app-db-infrastructure`
4. Visibility: Choose Public or Private
5. **Don't** initialize with README
6. Click "Create project"

## Step 2: Add Remote and Push

After creating the repository, you'll get a URL. Use one of these commands:

### HTTPS (Recommended for first time)
```bash
cd /home/wakama/terra/projects/learn-terra/app_db

# Replace YOUR_USERNAME and YOUR_REPO_NAME with your actual values
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO_NAME.git

# Push your code
git push -u origin master
```

### SSH (If you have SSH keys set up)
```bash
cd /home/wakama/terra/projects/learn-terra/app_db

# Replace YOUR_USERNAME and YOUR_REPO_NAME with your actual values
git remote add origin git@github.com:YOUR_USERNAME/YOUR_REPO_NAME.git

# Push your code
git push -u origin master
```

## Step 3: Verify

```bash
# Check remote is configured
git remote -v

# Should show:
# origin  https://github.com/YOUR_USERNAME/YOUR_REPO_NAME.git (fetch)
# origin  https://github.com/YOUR_USERNAME/YOUR_REPO_NAME.git (push)
```

## Troubleshooting

### If you get "fatal: remote origin already exists"
```bash
# Remove existing remote
git remote remove origin

# Add the correct remote
git remote add origin YOUR_REPO_URL
```

### If your default branch is 'main' instead of 'master'
```bash
# Push master branch to main on remote
git push -u origin master:main
```

### If you need to change the remote URL later
```bash
git remote set-url origin NEW_REPO_URL
```

## Quick Command Reference

```bash
# Add remote (HTTPS)
git remote add origin https://github.com/USERNAME/REPO.git

# Add remote (SSH)
git remote add origin git@github.com:USERNAME/REPO.git

# Push to remote
git push -u origin master

# Check remotes
git remote -v

# Remove remote
git remote remove origin
```

## Next Steps

After pushing:
1. ✅ Your code is now backed up in the cloud
2. ✅ You can access it from anywhere
3. ✅ Share it with potential employers/recruiters
4. ✅ Set up CI/CD workflows
5. ✅ Collaborate with others

