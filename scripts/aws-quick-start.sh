#!/bin/bash

# Discourse AWS Quick Start Script
# Sets up Discourse on a single EC2 instance with minimal configuration

set -e

echo "=============================================="
echo "Discourse AWS Quick Start"
echo "=============================================="
echo ""
echo "This script will help you deploy Discourse on AWS"
echo "in simple mode (single EC2 instance)."
echo ""

# Check prerequisites
if ! command -v aws &> /dev/null; then
    echo "ERROR: AWS CLI is not installed"
    echo "Install it from: https://aws.amazon.com/cli/"
    exit 1
fi

if ! command -v terraform &> /dev/null; then
    echo "ERROR: Terraform is not installed"
    echo "Install it from: https://www.terraform.io/downloads"
    exit 1
fi

# Collect information
echo "Please provide the following information:"
echo ""

read -p "AWS Region (e.g., us-east-1): " AWS_REGION
read -p "Project name (e.g., discourse): " PROJECT_NAME
read -p "Domain name (e.g., discourse.example.com): " DOMAIN_NAME
read -p "Admin email: " ADMIN_EMAIL
read -p "SSH key pair name (must exist in AWS): " SSH_KEY_NAME

echo ""
echo "Email Configuration (Amazon SES):"
read -p "SMTP address (e.g., email-smtp.us-east-1.amazonaws.com): " SMTP_ADDRESS
read -p "SMTP port (default 587): " SMTP_PORT
SMTP_PORT=${SMTP_PORT:-587}
read -p "SMTP username: " SMTP_USERNAME
read -sp "SMTP password: " SMTP_PASSWORD
echo ""

echo ""
echo "Instance Configuration:"
read -p "Instance type (default t3.small): " INSTANCE_TYPE
INSTANCE_TYPE=${INSTANCE_TYPE:-t3.small}

echo ""
echo "Creating Terraform configuration..."

# Create terraform.tfvars
cat > terraform/aws/terraform.tfvars <<EOF
# AWS Configuration
aws_region   = "$AWS_REGION"
project_name = "$PROJECT_NAME"
environment  = "production"

# Deployment Mode
deployment_mode = "simple"

# Domain Configuration
domain_name = "$DOMAIN_NAME"
admin_email = "$ADMIN_EMAIL"

# SSH Configuration
ssh_key_name = "$SSH_KEY_NAME"
allowed_ssh_cidr = ["0.0.0.0/0"]

# Email Configuration
smtp_address  = "$SMTP_ADDRESS"
smtp_port     = $SMTP_PORT
smtp_username = "$SMTP_USERNAME"
smtp_password = "$SMTP_PASSWORD"

# EC2 Configuration
instance_type = "$INSTANCE_TYPE"
EOF

echo "Configuration created!"
echo ""

# Initialize and deploy
cd terraform/aws

echo "Initializing Terraform..."
terraform init

echo ""
echo "Planning deployment..."
terraform plan -out=tfplan

echo ""
echo "=============================================="
echo "Review the plan above."
echo "=============================================="
echo ""
read -p "Deploy infrastructure? (yes/no): " DEPLOY

if [ "$DEPLOY" != "yes" ]; then
    echo "Deployment cancelled"
    exit 0
fi

echo ""
echo "Deploying infrastructure (this will take a few minutes)..."
terraform apply tfplan

echo ""
echo "=============================================="
echo "Deployment Complete!"
echo "=============================================="
echo ""

# Get outputs
INSTANCE_IP=$(terraform output -raw ec2_public_ip)
S3_BUCKET=$(terraform output -raw s3_bucket_name)

echo "Instance IP: $INSTANCE_IP"
echo "S3 Bucket: $S3_BUCKET"
echo ""
echo "Next steps:"
echo "1. Update your DNS:"
echo "   Create an A record: $DOMAIN_NAME -> $INSTANCE_IP"
echo ""
echo "2. Wait 10-15 minutes for Discourse to bootstrap"
echo ""
echo "3. Access Discourse:"
echo "   https://$DOMAIN_NAME"
echo ""
echo "4. SSH into instance (if needed):"
echo "   ssh -i ~/.ssh/$SSH_KEY_NAME.pem ubuntu@$INSTANCE_IP"
echo ""
echo "For detailed documentation, see:"
echo "  docs/AWS-DEPLOYMENT.md"
echo ""
echo "=============================================="
