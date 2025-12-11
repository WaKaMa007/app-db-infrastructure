# Deployment Promotion Checklist

Use this checklist for every change you promote through environments.

## 🔵 DEV Environment

- [ ] Make code changes in Terraform files
- [ ] Switch to dev workspace: `terraform workspace select dev`
- [ ] Review plan: `terraform plan`
- [ ] Apply changes: `terraform apply`
- [ ] Verify application functionality
- [ ] Test database connectivity
- [ ] Check CloudWatch logs for errors
- [ ] Validate all services are healthy
- [ ] **DEV VALIDATION COMPLETE** ✅

---

## 🟡 STAGING Environment

- [ ] Switch to staging: `terraform workspace select staging`
- [ ] Review plan differences from dev
  - [ ] Instance types changed correctly (t3.micro → t3.small)
  - [ ] Scaling configuration updated (1-2 → 1-3)
  - [ ] All changes from dev are included
- [ ] Apply changes: `terraform apply`
- [ ] Verify application functionality
- [ ] Perform load testing (if applicable)
- [ ] Test database performance
- [ ] Integration testing with other services
- [ ] Check monitoring and alerts
- [ ] **STAGING VALIDATION COMPLETE** ✅

---

## 🟢 PROD Environment

- [ ] Switch to prod: `terraform workspace select prod`
- [ ] Review plan carefully
  - [ ] Instance types: t3.medium (production-ready)
  - [ ] Scaling: 2-5 instances (high availability)
  - [ ] Deletion protection: **ENABLED** ✅
  - [ ] All changes from staging are included
- [ ] **PRODUCTION DEPLOYMENT APPROVAL**
- [ ] Apply changes: `terraform apply`
- [ ] Immediate post-deployment checks:
  - [ ] Application health endpoints responding
  - [ ] Database connections successful
  - [ ] No error spikes in CloudWatch
  - [ ] Load balancer health checks passing
- [ ] Extended monitoring (first 30 minutes):
  - [ ] Monitor CloudWatch metrics
  - [ ] Check application logs
  - [ ] Verify database performance
  - [ ] Monitor resource utilization
- [ ] **PROD VALIDATION COMPLETE** ✅

---

## 📝 Git Commit

- [ ] All environments validated successfully
- [ ] Review all changes: `git status` and `git diff`
- [ ] Stage changes: `git add .`
- [ ] Write descriptive commit message:
  ```bash
  git commit -m "feat: [Description of changes]
  
  - Change 1: Description
  - Change 2: Description
  - Deployed to: dev → staging → prod
  - All environments validated"
  ```
- [ ] Push to repository: `git push origin <branch>`
- [ ] **GIT COMMIT COMPLETE** ✅

---

## 🎯 Success Criteria

Before considering a promotion complete:

1. ✅ Application is accessible and functional
2. ✅ Database connections are stable
3. ✅ No critical errors in logs
4. ✅ Resource utilization is within expected ranges
5. ✅ Monitoring and alerts are functioning
6. ✅ Changes documented in Git

---

## ⚠️ Rollback Plan

If issues occur in any environment:

1. **Document the issue** (symptoms, logs, metrics)
2. **Revert the change** in Terraform code
3. **Apply revert** to the affected environment(s)
4. **Investigate root cause** in dev environment
5. **Fix and re-test** before promoting again

---

**Remember**: Never skip validation steps. Each environment serves a purpose!

