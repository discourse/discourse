# Terraform Configuration for Discourse on AWS

This directory contains Terraform configurations for deploying Discourse infrastructure on AWS.

## Overview

This Terraform setup provisions:

- VPC with public and private subnets across multiple availability zones
- EC2 instance(s) for running Discourse
- RDS PostgreSQL database (optional)
- ElastiCache Redis cluster (optional)
- S3 bucket for uploads and backups
- Security groups and IAM roles
- Application Load Balancer (optional, for production)
- Auto Scaling Group (optional, for production)

## Prerequisites

1. **AWS Account** with appropriate permissions
2. **AWS CLI** configured with credentials
3. **Terraform** installed (v1.0+)
4. **Domain name** registered and configured

## Quick Start

### 1. Install Terraform

```bash
# macOS
brew install terraform

# Linux
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/
```

### 2. Configure Variables

Copy the example variables file:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your values:

```hcl
# Required
aws_region        = "us-east-1"
project_name      = "discourse"
domain_name       = "discourse.example.com"
admin_email       = "admin@example.com"
ssh_key_name      = "your-aws-key-pair-name"

# Optional - Network
vpc_cidr = "10.0.0.0/16"

# Optional - Email
smtp_address  = "email-smtp.us-east-1.amazonaws.com"
smtp_port     = 587
smtp_username = "your-ses-smtp-username"
smtp_password = "your-ses-smtp-password"

# Optional - Instance
instance_type = "t3.small"  # or t3.medium for better performance

# Optional - Database
db_instance_class   = "db.t3.small"
db_allocated_storage = 20
enable_multi_az     = false  # set to true for production

# Optional - Redis
redis_node_type     = "cache.t3.small"
redis_num_replicas  = 0  # set to 1+ for production

# Deployment mode
deployment_mode = "simple"  # or "production" for full setup
```

### 3. Initialize Terraform

```bash
terraform init
```

### 4. Review the Plan

```bash
terraform plan
```

### 5. Apply Configuration

```bash
terraform apply
```

Review the changes and type `yes` to proceed.

### 6. Get Outputs

After successful deployment:

```bash
terraform output
```

This will show:
- EC2 instance public IP
- RDS endpoint (if enabled)
- ElastiCache endpoint (if enabled)
- S3 bucket name
- Load balancer DNS (if enabled)

## Deployment Modes

### Simple Mode (Default)

Provisions:
- Single EC2 instance
- PostgreSQL and Redis running in Docker containers
- Basic security group
- Elastic IP

**Best for**: Testing, small communities, development

```hcl
deployment_mode = "simple"
```

### Production Mode

Provisions:
- Auto Scaling Group with 2+ EC2 instances
- Application Load Balancer
- RDS PostgreSQL (Multi-AZ optional)
- ElastiCache Redis (with replicas optional)
- S3 bucket for uploads
- CloudWatch alarms

**Best for**: Production deployments, high availability

```hcl
deployment_mode = "production"
enable_multi_az = true
redis_num_replicas = 1
```

## File Structure

```
terraform/aws/
├── README.md                    # This file
├── main.tf                      # Main configuration
├── variables.tf                 # Variable definitions
├── outputs.tf                   # Output definitions
├── terraform.tfvars.example     # Example variables
├── modules/
│   ├── vpc/                     # VPC and networking
│   ├── security/                # Security groups and IAM
│   ├── compute/                 # EC2, ASG, ALB
│   ├── database/                # RDS PostgreSQL
│   ├── cache/                   # ElastiCache Redis
│   └── storage/                 # S3 buckets
└── scripts/
    └── user-data.sh             # EC2 initialization script
```

## Managing Infrastructure

### View Current State

```bash
terraform show
```

### Update Infrastructure

After modifying variables:

```bash
terraform plan
terraform apply
```

### Destroy Infrastructure

**Warning**: This will delete all resources!

```bash
terraform destroy
```

### Target Specific Resources

```bash
# Apply changes to specific module
terraform apply -target=module.compute

# Destroy specific resource
terraform destroy -target=aws_instance.discourse
```

## Common Operations

### Scaling EC2 Instance

1. Edit `terraform.tfvars`:
   ```hcl
   instance_type = "t3.medium"  # upgrade from t3.small
   ```

2. Apply changes:
   ```bash
   terraform apply
   ```

   This will stop and resize the instance.

### Enabling Multi-AZ for RDS

1. Edit `terraform.tfvars`:
   ```hcl
   enable_multi_az = true
   ```

2. Apply changes:
   ```bash
   terraform apply
   ```

### Adding Redis Replicas

1. Edit `terraform.tfvars`:
   ```hcl
   redis_num_replicas = 1
   ```

2. Apply changes:
   ```bash
   terraform apply
   ```

## Outputs

After deployment, Terraform provides:

```
ec2_public_ip          = "xxx.xxx.xxx.xxx"
ec2_instance_id        = "i-xxxxx"
rds_endpoint           = "discourse-db.xxxxx.rds.amazonaws.com:5432"
redis_endpoint         = "discourse-redis.xxxxx.cache.amazonaws.com:6379"
s3_bucket_name         = "discourse-uploads-xxxxx"
alb_dns_name           = "discourse-alb-xxxxx.us-east-1.elb.amazonaws.com"
```

Use these values to:
1. Configure DNS A record
2. SSH into instance
3. Configure Discourse `app.yml`

## Post-Deployment Steps

### 1. Configure DNS

Point your domain to the instance IP or load balancer:

```bash
# Get the IP/DNS
terraform output ec2_public_ip
# or
terraform output alb_dns_name
```

Create an A record or CNAME in Route 53 or your DNS provider.

### 2. SSH into Instance

```bash
# Get the public IP
IP=$(terraform output -raw ec2_public_ip)

# Connect
ssh -i ~/.ssh/your-key.pem ubuntu@$IP
```

### 3. Configure Discourse

If using production mode with external services:

```bash
# Edit app.yml with the endpoints
cd /var/discourse
nano containers/app.yml
```

Add the outputs from Terraform:

```yaml
env:
  DISCOURSE_DB_HOST: $(terraform output -raw rds_endpoint | cut -d: -f1)
  DISCOURSE_REDIS_HOST: $(terraform output -raw redis_endpoint | cut -d: -f1)
  DISCOURSE_S3_BUCKET: $(terraform output -raw s3_bucket_name)
```

Then rebuild:

```bash
./launcher rebuild app
```

## Cost Estimation

### Simple Mode (~$20-25/month)
- EC2 t3.small: ~$15
- EBS 20GB: ~$2
- Elastic IP: ~$0
- Data transfer: ~$5

### Production Mode (~$100-150/month)
- EC2 (2x t3.small): ~$30
- ALB: ~$20
- RDS db.t3.small: ~$25
- ElastiCache cache.t3.small: ~$25
- S3: ~$1-5
- Data transfer: ~$10-20

Use AWS Cost Calculator for accurate estimates: https://calculator.aws/

## Troubleshooting

### Issue: Terraform can't authenticate

```bash
# Configure AWS CLI
aws configure

# Or set environment variables
export AWS_ACCESS_KEY_ID="your-key"
export AWS_SECRET_ACCESS_KEY="your-secret"
export AWS_DEFAULT_REGION="us-east-1"
```

### Issue: Resource already exists

```bash
# Import existing resource
terraform import aws_instance.discourse i-xxxxx

# Or remove from state
terraform state rm aws_instance.discourse
```

### Issue: Cannot destroy VPC

```bash
# Dependencies must be destroyed first
terraform destroy -target=module.compute
terraform destroy -target=module.database
terraform destroy -target=module.vpc
```

### Issue: State lock error

```bash
# Force unlock (use with caution)
terraform force-unlock <lock-id>
```

## Best Practices

1. **Use Remote State**: Store state in S3 with DynamoDB locking
2. **Workspace for Environments**: Use `terraform workspace` for dev/staging/prod
3. **Version Control**: Commit `.tf` files, not `terraform.tfvars`
4. **Module Versioning**: Pin module versions for stability
5. **Secrets Management**: Use AWS Secrets Manager or Parameter Store
6. **Tagging**: Add comprehensive tags for resource management

## Security Considerations

1. **Never commit secrets** to version control
2. **Use IAM roles** instead of access keys when possible
3. **Enable MFA** on AWS root and IAM accounts
4. **Restrict SSH access** to specific IP ranges
5. **Enable VPC Flow Logs** for network monitoring
6. **Use AWS Secrets Manager** for database passwords
7. **Enable encryption** for RDS, S3, and EBS volumes

## Advanced Configuration

### Using Remote State

Create `backend.tf`:

```hcl
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "discourse/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}
```

### Multiple Environments

```bash
# Create workspaces
terraform workspace new dev
terraform workspace new staging
terraform workspace new prod

# Switch between environments
terraform workspace select prod
terraform apply -var-file=prod.tfvars
```

### Custom Domain with Route 53

Add to `terraform.tfvars`:

```hcl
create_route53_record = true
route53_zone_id      = "Z1234567890ABC"
```

## Additional Resources

- [Terraform AWS Provider Docs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [Discourse Meta Forum](https://meta.discourse.org)

## Support

- GitHub Issues: For Terraform configuration issues
- Discourse Meta: For Discourse-specific questions
- AWS Support: For AWS service issues
