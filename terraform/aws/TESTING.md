# AWS Deployment Testing Checklist

This checklist helps you verify the Terraform configuration before deploying to production.

## ✅ Pre-Deployment Validation

### 1. Code Review Issues Fixed
- [x] Added `random` provider to main.tf (required for random_string and random_password resources)

### 2. Prerequisites Check

Before running Terraform, ensure you have:

- [ ] AWS CLI installed and configured (`aws --version`)
- [ ] AWS credentials configured (`aws sts get-caller-identity`)
- [ ] Terraform installed (`terraform version` - requires >= 1.0)
- [ ] SSH key pair created in AWS (note the name for terraform.tfvars)
- [ ] Domain name registered
- [ ] Email service configured (Amazon SES or third-party SMTP)

### 3. Configuration Validation

Review `terraform.tfvars` and verify:

- [ ] `aws_region` is a valid AWS region
- [ ] `domain_name` is your actual domain
- [ ] `admin_email` is accessible
- [ ] `ssh_key_name` matches your AWS key pair name
- [ ] `smtp_*` credentials are correct
- [ ] `deployment_mode` is "simple" or "production"
- [ ] `instance_type` is appropriate for your needs

### 4. Terraform Syntax Validation

```bash
cd terraform/aws
terraform init
terraform validate
terraform fmt -check
```

Expected results:
- `terraform init`: Downloads providers successfully
- `terraform validate`: "Success! The configuration is valid."
- `terraform fmt -check`: No formatting issues

### 5. Terraform Plan Review

```bash
terraform plan -out=tfplan
```

Review the plan and verify:

- [ ] Resource counts match expectations
  - Simple mode: ~25-30 resources
  - Production mode: ~40-50 resources
- [ ] No unexpected deletions
- [ ] Security groups have correct ingress/egress rules
- [ ] IAM roles have appropriate permissions
- [ ] S3 bucket configuration includes encryption and versioning

## 🧪 Testing Strategy

### Phase 1: Simple Mode Testing (Recommended First)

1. **Deploy in Simple Mode**
   ```bash
   # In terraform.tfvars
   deployment_mode = "simple"
   instance_type = "t3.small"
   ```

2. **Expected Resources Created:**
   - 1 VPC with subnets
   - 1 EC2 instance
   - 1 Elastic IP
   - 1 S3 bucket
   - Security groups
   - IAM role and instance profile

3. **Validation Steps:**
   - [ ] EC2 instance launches successfully
   - [ ] Elastic IP is associated
   - [ ] Can SSH into instance: `ssh -i ~/.ssh/key.pem ubuntu@<IP>`
   - [ ] Docker is installed: `docker --version`
   - [ ] Discourse Docker is cloned: `ls /var/discourse`
   - [ ] User data script completed: `tail -100 /var/log/user-data.log`
   - [ ] Discourse is running: `cd /var/discourse && ./launcher logs app`

4. **Cost:** ~$22/month

### Phase 2: Production Mode Testing (After Simple Mode Works)

1. **Deploy in Production Mode**
   ```bash
   # In terraform.tfvars
   deployment_mode = "production"
   enable_multi_az = false  # Start with single-AZ for testing
   redis_num_replicas = 0   # Start without replicas
   ```

2. **Expected Additional Resources:**
   - RDS PostgreSQL instance
   - ElastiCache Redis cluster
   - Application Load Balancer
   - Auto Scaling Group
   - Target Group
   - Additional CloudWatch alarms

3. **Validation Steps:**
   - [ ] RDS instance is available
   - [ ] Can connect to RDS from EC2 (test in user-data logs)
   - [ ] ElastiCache cluster is available
   - [ ] ALB is active and healthy
   - [ ] ASG launches instances
   - [ ] Target group health checks pass
   - [ ] Can access Discourse via ALB DNS

4. **Cost:** ~$100-150/month (testing) / ~$300/month (full HA)

## 🔍 Known Issues to Watch For

### Issue 1: RDS Endpoint Format
**Symptom:** Database connection fails
**Check:** RDS endpoint in outputs should be `hostname:port` format
**Fix:** Verified in database module outputs

### Issue 2: ElastiCache Endpoint
**Symptom:** Redis connection fails
**Check:** ElastiCache endpoint should be hostname only (no port in address)
**Fix:** Port is separate output (6379)

### Issue 3: User Data Script Template
**Symptom:** EC2 launches but Discourse doesn't configure
**Check:** `/var/log/user-data.log` for template variable errors
**Fix:** Template syntax uses `%{ if }` ... `%{ endif }` format

### Issue 4: S3 Bucket Permissions
**Symptom:** Discourse can't upload to S3
**Check:** IAM instance profile has S3 permissions
**Fix:** security module includes S3 policy for the IAM role

### Issue 5: SES Sandbox Mode
**Symptom:** Emails don't send
**Check:** Amazon SES is in sandbox mode by default
**Fix:** Request production access through SES console

## 🔧 Testing Commands

### Test AWS Connectivity
```bash
aws sts get-caller-identity
aws ec2 describe-regions --region us-east-1
```

### Test Terraform Configuration
```bash
cd terraform/aws
terraform init
terraform validate
terraform plan
```

### Test After Deployment

**SSH into Instance:**
```bash
# Get IP from output
terraform output ec2_public_ip
ssh -i ~/.ssh/your-key.pem ubuntu@<IP>
```

**Check Logs:**
```bash
# On EC2 instance
sudo tail -f /var/log/user-data.log
cd /var/discourse && ./launcher logs app
```

**Check Discourse Status:**
```bash
cd /var/discourse
./launcher enter app
discourse version
```

**Test Database Connection (Production Mode):**
```bash
# On EC2 instance
psql -h <RDS_ENDPOINT> -U discourse -d discourse_production
```

**Test Redis Connection (Production Mode):**
```bash
# On EC2 instance
redis-cli -h <REDIS_ENDPOINT> ping
```

## 📊 Success Criteria

### Simple Mode Success
- [ ] Terraform apply completes without errors
- [ ] EC2 instance is running
- [ ] Can SSH into instance
- [ ] Discourse Docker container is running
- [ ] Can access Discourse via domain (after DNS propagates)
- [ ] Can create admin account
- [ ] Can create test post
- [ ] Uploads work (stored in S3)

### Production Mode Success
- [ ] All Simple Mode criteria met
- [ ] RDS database is accessible
- [ ] Redis cache is accessible
- [ ] ALB health checks pass
- [ ] Can access via ALB DNS
- [ ] Auto scaling works (manually trigger scale event)
- [ ] CloudWatch metrics appear
- [ ] Backups are created in S3

## 🚨 Rollback Plan

If issues occur:

```bash
# Destroy infrastructure
cd terraform/aws
terraform destroy

# Review errors
cat terraform.log

# Fix issues in code or configuration
# Re-deploy
terraform plan
terraform apply
```

## 📝 Reporting Issues

If you find bugs in the Terraform code, please report:

1. **Terraform version:** `terraform version`
2. **AWS region:** From terraform.tfvars
3. **Deployment mode:** simple or production
4. **Error message:** Full terraform error output
5. **Expected behavior:** What should happen
6. **Actual behavior:** What actually happened
7. **Steps to reproduce:** Exact commands run

## 🎯 Next Steps After Successful Test

1. **Configure DNS properly** (not just testing)
2. **Set up monitoring alerts**
3. **Configure automated backups**
4. **Review security settings**
5. **Enable Multi-AZ** (production mode)
6. **Add Redis replicas** (production mode)
7. **Configure auto-scaling policies**
8. **Set up CloudWatch dashboards**
9. **Test disaster recovery** procedures
10. **Document your specific configuration**

## 💰 Cost Management During Testing

- **Use t3.micro/t3.small** instances for testing
- **Disable Multi-AZ** during initial tests
- **No Redis replicas** during testing
- **Destroy infrastructure** when not actively testing
- **Set up billing alerts** at $50, $100 thresholds
- **Use AWS Cost Explorer** to monitor actual costs

## ✨ Estimated Testing Timeline

- **Phase 1 (Simple Mode):** 2-4 hours
  - 30 min: Configuration
  - 30 min: Terraform deployment
  - 15 min: Bootstrap time
  - 1-2 hours: Testing and validation

- **Phase 2 (Production Mode):** 4-6 hours
  - 30 min: Configuration updates
  - 45 min: Terraform deployment
  - 15 min: Bootstrap time
  - 2-4 hours: Testing all components

- **Total:** 1-2 days for thorough testing

## 📞 Getting Help

- **Terraform issues:** Review error messages carefully
- **AWS issues:** Check AWS Console for resource status
- **Discourse issues:** Check `/var/discourse/shared/standalone/log/rails/production.log`
- **General questions:** See docs/AWS-DEPLOYMENT.md
