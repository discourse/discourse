# Deploy Discourse on AWS

Complete guide for self-hosting Discourse on Amazon Web Services (AWS).

## Table of Contents

1. [Overview](#overview)
2. [AWS Architecture](#aws-architecture)
3. [Prerequisites](#prerequisites)
4. [Deployment Options](#deployment-options)
5. [Quick Start - Single EC2 Instance](#quick-start---single-ec2-instance)
6. [Production Setup - Managed Services](#production-setup---managed-services)
7. [Post-Deployment Configuration](#post-deployment-configuration)
8. [Scaling and High Availability](#scaling-and-high-availability)
9. [Backup and Disaster Recovery](#backup-and-disaster-recovery)
10. [Monitoring and Maintenance](#monitoring-and-maintenance)
11. [Cost Optimization](#cost-optimization)

## Overview

This guide covers deploying Discourse on AWS using Docker. You can choose between:

- **Simple Setup**: Single EC2 instance with Docker (similar to DigitalOcean setup)
- **Production Setup**: EC2 + RDS (PostgreSQL) + ElastiCache (Redis) + S3

## AWS Architecture

### Simple Architecture (Beginner)
```
┌─────────────────────────────────────┐
│           EC2 Instance              │
│  ┌──────────────────────────────┐   │
│  │   Discourse Docker Container │   │
│  │  - Rails App                 │   │
│  │  - PostgreSQL                │   │
│  │  - Redis                     │   │
│  │  - Nginx                     │   │
│  └──────────────────────────────┘   │
└─────────────────────────────────────┘
         │
         ▼
   Route 53 (DNS)
```

### Production Architecture (Recommended)
```
┌──────────────┐    ┌─────────────────────────┐
│  Route 53    │───▶│  Application Load       │
│   (DNS)      │    │  Balancer (ALB)         │
└──────────────┘    └─────────────────────────┘
                              │
                    ┌─────────┴─────────┐
                    ▼                   ▼
            ┌──────────────┐    ┌──────────────┐
            │   EC2 Auto   │    │   EC2 Auto   │
            │   Scaling    │    │   Scaling    │
            │   Group      │    │   Group      │
            │  (Discourse) │    │  (Discourse) │
            └──────────────┘    └──────────────┘
                    │                   │
        ┌───────────┼───────────────────┼───────────┐
        ▼           ▼                   ▼           ▼
   ┌────────┐  ┌─────────┐       ┌─────────┐  ┌────────┐
   │  RDS   │  │ElastiCache│      │   S3    │  │ CloudWatch│
   │Postgres│  │  Redis   │      │ Uploads │  │Monitoring│
   └────────┘  └─────────┘       └─────────┘  └────────┘
```

## Prerequisites

### Required

1. **AWS Account** with appropriate permissions
2. **Domain Name** (e.g., discourse.example.com)
3. **Email Service** for transactional emails:
   - Amazon SES (Simple Email Service)
   - Mailgun
   - SendGrid
   - Postmark

### Tools to Install Locally

- AWS CLI v2: https://aws.amazon.com/cli/
- Terraform (optional, for IaC): https://www.terraform.io/downloads
- SSH client

### AWS Services Knowledge

Basic familiarity with:
- EC2 (Virtual Servers)
- Security Groups (Firewall)
- Route 53 (DNS)
- Optional: RDS, ElastiCache, S3, CloudWatch

## Deployment Options

### Option 1: Quick Start - Single EC2 Instance

**Best for:**
- Testing/Development
- Small communities (<1000 users)
- Budget-conscious deployments
- Getting started quickly

**Pros:**
- Simple setup
- Lower cost
- Easy to manage

**Cons:**
- Single point of failure
- Limited scalability
- Shared resources

### Option 2: Production Setup - Managed Services

**Best for:**
- Production communities
- Medium to large deployments
- High availability requirements
- Scalable infrastructure

**Pros:**
- Managed PostgreSQL (RDS)
- Managed Redis (ElastiCache)
- Automated backups
- Easy scaling
- High availability

**Cons:**
- Higher cost
- More complex setup
- Requires AWS expertise

## Quick Start - Single EC2 Instance

This section mirrors the standard cloud installation but tailored for AWS.

### Step 1: Prepare Your Domain Name

1. Purchase a domain if you don't have one
2. Access Route 53 or your DNS provider
3. Prepare to create an A record for `discourse.yourdomain.com`

### Step 2: Configure Email (Amazon SES)

#### Option A: Amazon SES (Recommended for AWS)

1. **Navigate to Amazon SES Console**
   - Go to https://console.aws.amazon.com/ses/

2. **Verify Your Domain**
   - Click "Verified identities"
   - Click "Create identity"
   - Choose "Domain"
   - Enter your domain name
   - Enable DKIM signing
   - Copy the DNS records provided

3. **Add DNS Records**
   - Add DKIM records to Route 53 or your DNS provider
   - Add SPF record: `v=spf1 include:amazonses.com ~all`

4. **Request Production Access**
   - By default, SES is in sandbox mode
   - Request production access via the SES console
   - This usually takes 24-48 hours

5. **Create SMTP Credentials**
   - Go to "SMTP settings" in SES
   - Click "Create SMTP credentials"
   - Save the username and password securely
   - Note the SMTP endpoint for your region:
     - US East (N. Virginia): `email-smtp.us-east-1.amazonaws.com`
     - US West (Oregon): `email-smtp.us-west-2.amazonaws.com`
     - EU (Ireland): `email-smtp.eu-west-1.amazonaws.com`

#### Option B: Third-Party Email Service

Follow the standard [email setup guide](INSTALL-email.md).

### Step 3: Launch EC2 Instance

1. **Login to AWS Console**
   - Navigate to EC2: https://console.aws.amazon.com/ec2/

2. **Launch Instance**
   - Click "Launch Instance"

   **Instance Configuration:**
   - **Name**: `discourse-production`
   - **AMI**: Ubuntu Server 22.04 LTS (64-bit x86)
   - **Instance Type**:
     - Minimum: `t3.small` (2GB RAM)
     - Recommended: `t3.medium` (4GB RAM) or `t3a.medium`
   - **Key Pair**: Create or select an existing SSH key pair
   - **Storage**: 20 GB gp3 SSD minimum (30GB recommended)

3. **Configure Security Group**

   Create a new security group with these rules:

   | Type  | Protocol | Port Range | Source       | Description           |
   |-------|----------|------------|--------------|---------------------- |
   | SSH   | TCP      | 22         | Your IP      | SSH access            |
   | HTTP  | TCP      | 80         | 0.0.0.0/0    | HTTP traffic          |
   | HTTPS | TCP      | 443        | 0.0.0.0/0    | HTTPS traffic         |
   | SMTP  | TCP      | 587        | 0.0.0.0/0    | Outbound email (optional) |

   **Important**: Restrict SSH (port 22) to your IP address only for security.

4. **Launch the Instance**
   - Review and click "Launch Instance"
   - Note the public IP address

5. **Configure Elastic IP (Recommended)**
   - Navigate to "Elastic IPs" in EC2
   - Click "Allocate Elastic IP address"
   - Associate it with your instance
   - This ensures your IP doesn't change on restart

### Step 4: Configure DNS

1. **Create A Record in Route 53**
   - Go to Route 53 console
   - Select your hosted zone
   - Click "Create record"
   - Record name: `discourse` (or your chosen subdomain)
   - Record type: `A`
   - Value: Your EC2 instance's Elastic IP
   - TTL: 300
   - Click "Create records"

2. **Verify DNS Propagation**
   ```bash
   nslookup discourse.yourdomain.com
   ```

### Step 5: Connect to Your EC2 Instance

```bash
# Change permissions on your key file
chmod 400 your-key.pem

# Connect via SSH
ssh -i your-key.pem ubuntu@discourse.yourdomain.com
```

### Step 6: Install Docker

```bash
# Update package index
sudo apt update

# Install prerequisites
sudo apt install -y git

# Install Docker using official script
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add ubuntu user to docker group
sudo usermod -aG docker ubuntu

# Verify installation
sudo docker --version
```

### Step 7: Install Discourse

```bash
# Switch to root
sudo -s

# Clone Discourse Docker repository
git clone https://github.com/discourse/discourse_docker.git /var/discourse
cd /var/discourse

# Set permissions
chmod 700 containers
```

### Step 8: Configure Discourse

```bash
# Run the setup wizard
./discourse-setup
```

**Answer the prompts:**

```
Hostname for your Discourse? [discourse.example.com]:
discourse.yourdomain.com

Email address for admin account(s)? [me@example.com,you@example.com]:
admin@yourdomain.com

SMTP server address? [smtp.example.com]:
email-smtp.us-east-1.amazonaws.com

SMTP port? [587]:
587

SMTP user name? [user@example.com]:
[Your SES SMTP username]

SMTP password? [pa$$word]:
[Your SES SMTP password]

Let's Encrypt account email? (ENTER to skip) [me@example.com]:
admin@yourdomain.com

Optional Maxmind License key () [xxxxxxxxxxxxxxxx]:
[Press ENTER to skip]
```

The script will:
- Create `containers/app.yml` configuration
- Bootstrap the Docker container (takes 5-10 minutes)
- Start Discourse

### Step 9: Access Your Discourse Instance

1. Open your browser to `https://discourse.yourdomain.com`
2. Register an admin account using the email you specified
3. Check your email for the activation link
4. Complete the setup wizard

### Step 10: Post-Installation Security

```bash
# Enable automatic security updates
sudo dpkg-reconfigure -plow unattended-upgrades

# Install and configure fail2ban
sudo apt install -y fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban

# Configure UFW firewall (optional but recommended)
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

## Production Setup - Managed Services

For production deployments with managed AWS services (RDS, ElastiCache, S3).

### Architecture Overview

- **EC2 Auto Scaling Group**: Run Discourse containers
- **Application Load Balancer**: Distribute traffic
- **RDS PostgreSQL**: Managed database
- **ElastiCache Redis**: Managed cache
- **S3**: Store uploads and backups
- **CloudWatch**: Monitoring and logging

### Step 1: Create VPC and Networking

```bash
# Use provided Terraform configuration
cd terraform/aws
terraform init
terraform plan
terraform apply
```

See `terraform/aws/README.md` for detailed instructions.

### Step 2: Create RDS PostgreSQL Instance

1. **Navigate to RDS Console**

2. **Create Database**
   - Engine: PostgreSQL 15.x
   - Template: Production
   - DB instance identifier: `discourse-db`
   - Master username: `discourse`
   - Master password: [Generate strong password]
   - Instance class: `db.t3.small` or larger
   - Storage: 20GB gp3, enable autoscaling to 100GB
   - Multi-AZ: Yes (for production)
   - VPC: Select your VPC
   - Subnet group: Create new private subnet group
   - Public access: No
   - Security group: Create new (allow PostgreSQL from EC2 security group)

3. **Note the Endpoint**
   - Example: `discourse-db.xxxxx.us-east-1.rds.amazonaws.com:5432`

### Step 3: Create ElastiCache Redis Cluster

1. **Navigate to ElastiCache Console**

2. **Create Redis Cluster**
   - Cluster mode: Disabled
   - Name: `discourse-redis`
   - Engine version: 7.0.x
   - Node type: `cache.t3.small` or larger
   - Number of replicas: 1 (for production)
   - VPC: Select your VPC
   - Subnet group: Create new private subnet group
   - Security group: Create new (allow Redis from EC2 security group)

3. **Note the Endpoint**
   - Example: `discourse-redis.xxxxx.0001.use1.cache.amazonaws.com:6379`

### Step 4: Create S3 Bucket for Uploads

```bash
# Create bucket (replace with your bucket name)
aws s3 mb s3://discourse-uploads-yourdomain

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket discourse-uploads-yourdomain \
  --versioning-configuration Status=Enabled

# Configure CORS
cat > cors.json <<EOF
{
  "CORSRules": [
    {
      "AllowedOrigins": ["https://discourse.yourdomain.com"],
      "AllowedMethods": ["GET", "PUT", "POST", "DELETE"],
      "AllowedHeaders": ["*"],
      "MaxAgeSeconds": 3000
    }
  ]
}
EOF

aws s3api put-bucket-cors \
  --bucket discourse-uploads-yourdomain \
  --cors-configuration file://cors.json
```

### Step 5: Create IAM Role for EC2

```bash
# Create IAM role with S3 access
cat > trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

aws iam create-role \
  --role-name discourse-ec2-role \
  --assume-role-policy-document file://trust-policy.json

# Attach S3 policy
cat > s3-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::discourse-uploads-yourdomain/*",
        "arn:aws:s3:::discourse-uploads-yourdomain"
      ]
    }
  ]
}
EOF

aws iam put-role-policy \
  --role-name discourse-ec2-role \
  --policy-name discourse-s3-access \
  --policy-document file://s3-policy.json

# Create instance profile
aws iam create-instance-profile \
  --instance-profile-name discourse-ec2-profile

aws iam add-role-to-instance-profile \
  --instance-profile-name discourse-ec2-profile \
  --role-name discourse-ec2-role
```

### Step 6: Configure Discourse for External Services

Edit `/var/discourse/containers/app.yml`:

```yaml
env:
  LANG: en_US.UTF-8

  # Database (RDS)
  DISCOURSE_DB_HOST: discourse-db.xxxxx.us-east-1.rds.amazonaws.com
  DISCOURSE_DB_PORT: 5432
  DISCOURSE_DB_NAME: discourse_production
  DISCOURSE_DB_USERNAME: discourse
  DISCOURSE_DB_PASSWORD: 'your-rds-password'

  # Redis (ElastiCache)
  DISCOURSE_REDIS_HOST: discourse-redis.xxxxx.0001.use1.cache.amazonaws.com
  DISCOURSE_REDIS_PORT: 6379

  # S3 Configuration
  DISCOURSE_USE_S3: true
  DISCOURSE_S3_REGION: us-east-1
  DISCOURSE_S3_BUCKET: discourse-uploads-yourdomain
  DISCOURSE_S3_CDN_URL: https://discourse-uploads-yourdomain.s3.amazonaws.com

  # Email (SES)
  DISCOURSE_SMTP_ADDRESS: email-smtp.us-east-1.amazonaws.com
  DISCOURSE_SMTP_PORT: 587
  DISCOURSE_SMTP_USER_NAME: your-ses-smtp-username
  DISCOURSE_SMTP_PASSWORD: your-ses-smtp-password

  # Site Configuration
  DISCOURSE_HOSTNAME: discourse.yourdomain.com
  DISCOURSE_DEVELOPER_EMAILS: admin@yourdomain.com
```

Then rebuild:

```bash
cd /var/discourse
./launcher rebuild app
```

## Post-Deployment Configuration

### Configure AWS Backups

#### Option 1: AWS Backup Service

1. Navigate to AWS Backup Console
2. Create backup plan
3. Add your RDS instance to the backup plan
4. Configure retention policy

#### Option 2: Discourse Built-in Backups to S3

In Discourse admin panel:
1. Go to Settings → Backups
2. Enable backups
3. Configure S3 backup location
4. Set backup frequency

### Configure CloudWatch Monitoring

```bash
# Install CloudWatch agent on EC2
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
sudo dpkg -i amazon-cloudwatch-agent.deb

# Configure agent
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-config-wizard
```

Monitor:
- CPU utilization
- Memory usage
- Disk I/O
- Network traffic
- Application logs

### Configure Auto Scaling (Optional)

For high-traffic sites:

1. Create Launch Template from your EC2 instance
2. Create Auto Scaling Group
3. Configure scaling policies:
   - Target CPU: 70%
   - Min instances: 2
   - Max instances: 10
4. Attach Application Load Balancer

## Scaling and High Availability

### Vertical Scaling (Bigger Instance)

```bash
# Stop Discourse
cd /var/discourse
./launcher stop app

# Stop EC2 instance and change instance type via AWS Console
# Then restart and start Discourse

./launcher start app
```

### Horizontal Scaling (Multiple Instances)

Requirements:
- RDS PostgreSQL (not local DB)
- ElastiCache Redis (not local Redis)
- S3 for uploads
- Application Load Balancer
- Auto Scaling Group

### Multi-Region Setup

For global audiences:
1. Deploy Discourse in multiple AWS regions
2. Use Route 53 geolocation routing
3. Replicate data between regions

## Backup and Disaster Recovery

### Automated Backups

**RDS Automated Backups:**
- Enabled by default
- 7-35 day retention
- Point-in-time recovery

**S3 Versioning:**
- Enabled for uploads bucket
- Protect against accidental deletion

**Discourse Backups:**
```bash
# Manual backup
cd /var/discourse
./launcher enter app
rake backup:create

# Backups stored in S3 if configured
```

### Disaster Recovery Plan

1. **Regular Testing**: Test restore procedures quarterly
2. **Documentation**: Keep infrastructure documentation updated
3. **RTO/RPO**: Define Recovery Time/Point Objectives
4. **Monitoring**: Set up alerts for critical issues

### Restore Procedure

```bash
# Restore from Discourse backup
cd /var/discourse
./launcher enter app
rake backup:restore FILENAME=backup-file.tar.gz
```

## Monitoring and Maintenance

### CloudWatch Alarms

Set up alarms for:
- EC2 CPU > 80%
- RDS CPU > 80%
- RDS Free Storage < 10GB
- ElastiCache CPU > 80%
- Application errors

### Regular Maintenance

**Weekly:**
- Review CloudWatch metrics
- Check application logs
- Monitor disk usage

**Monthly:**
- Review security patches
- Update Discourse via admin panel
- Test backup restoration
- Review AWS costs

**Quarterly:**
- Security audit
- Performance optimization
- Review scaling policies

### Upgrading Discourse

```bash
# Via web interface
# Go to https://discourse.yourdomain.com/admin/upgrade
# Click "Upgrade to Latest Version"

# Or via command line
cd /var/discourse
./launcher rebuild app
```

## Cost Optimization

### Estimated Monthly Costs (US-East-1)

**Small Setup (Single EC2):**
- EC2 t3.small: ~$15/month
- 20GB EBS: ~$2/month
- Data transfer: ~$5/month
- **Total: ~$22/month**

**Medium Setup (EC2 + RDS + ElastiCache):**
- EC2 t3.medium: ~$30/month
- RDS db.t3.small: ~$25/month
- ElastiCache cache.t3.small: ~$25/month
- S3 storage (50GB): ~$1/month
- Data transfer: ~$10/month
- **Total: ~$91/month**

**Large Setup (HA with Multi-AZ):**
- EC2 (2x t3.large): ~$120/month
- RDS Multi-AZ db.t3.medium: ~$95/month
- ElastiCache with replica: ~$50/month
- ALB: ~$20/month
- S3 + CloudWatch: ~$15/month
- **Total: ~$300/month**

### Cost Saving Tips

1. **Use Reserved Instances**: Save up to 70% for 1-3 year commitments
2. **Use Spot Instances**: For dev/test environments
3. **Right-size Instances**: Use CloudWatch to identify underutilized resources
4. **Enable S3 Lifecycle Policies**: Move old backups to Glacier
5. **Use AWS Budgets**: Set spending alerts
6. **Clean Up Resources**: Delete unused snapshots, AMIs, EBS volumes
7. **Use t3/t3a Instance Types**: Burstable performance at lower cost

### Monitoring Costs

```bash
# Install AWS Cost and Usage Reports
# Enable in AWS Billing Dashboard

# Use AWS Cost Explorer to track spending
# Set up Budget Alerts in AWS Budgets
```

## Troubleshooting

### Common Issues

**Issue: Cannot connect to instance**
```bash
# Check security group allows SSH from your IP
# Verify key pair permissions: chmod 400 your-key.pem
# Check EC2 instance is running
```

**Issue: Email not working**
```bash
# Verify SES is out of sandbox mode
# Check SMTP credentials are correct
# Verify security group allows outbound on port 587
# Check Discourse logs: /var/discourse/shared/standalone/log/rails/production.log
```

**Issue: Discourse won't start**
```bash
# Check Docker logs
cd /var/discourse
./launcher logs app

# Restart container
./launcher restart app
```

**Issue: Out of memory**
```bash
# Check instance type has at least 2GB RAM
# Add swap file
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

**Issue: Cannot connect to RDS**
```bash
# Verify security group allows PostgreSQL from EC2 security group
# Check RDS endpoint is correct in app.yml
# Verify VPC and subnet configuration
```

### Getting Help

- Discourse Meta: https://meta.discourse.org
- AWS Documentation: https://docs.aws.amazon.com
- Discourse Docker Repo: https://github.com/discourse/discourse_docker

## Next Steps

1. **Configure Plugins**: Install additional features from https://meta.discourse.org/c/plugin
2. **Customize Theme**: Create a custom theme for your community
3. **Set up CDN**: Use AWS CloudFront for faster global delivery
4. **Configure SSO**: Integrate with existing authentication systems
5. **Set up Reply via Email**: Allow users to reply to topics via email

## Additional Resources

- [Discourse Admin Quick Start Guide](https://meta.discourse.org/t/discourse-admin-quick-start-guide/47370)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [Discourse Performance Best Practices](https://meta.discourse.org/t/performance-improvements/18307)

---

**Questions or Issues?**

- Open an issue in this repository
- Ask on [meta.discourse.org](https://meta.discourse.org)
- Consult AWS Support for AWS-specific issues
