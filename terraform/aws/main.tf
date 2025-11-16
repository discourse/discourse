terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      ManagedBy   = "Terraform"
      Environment = var.environment
    }
  }
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# VPC Module
module "vpc" {
  source = "./modules/vpc"

  project_name         = var.project_name
  vpc_cidr             = var.vpc_cidr
  availability_zones   = data.aws_availability_zones.available.names
  enable_nat_gateway   = var.deployment_mode == "production"
  single_nat_gateway   = var.deployment_mode == "simple"
}

# Security Module
module "security" {
  source = "./modules/security"

  project_name = var.project_name
  vpc_id       = module.vpc.vpc_id
  allowed_ssh_cidr = var.allowed_ssh_cidr
}

# Storage Module (S3)
module "storage" {
  source = "./modules/storage"

  project_name = var.project_name
  domain_name  = var.domain_name
  enable_versioning = var.enable_s3_versioning
}

# Database Module (RDS)
module "database" {
  source = "./modules/database"
  count  = var.deployment_mode == "production" ? 1 : 0

  project_name          = var.project_name
  vpc_id                = module.vpc.vpc_id
  subnet_ids            = module.vpc.private_subnet_ids
  security_group_id     = module.security.rds_security_group_id
  instance_class        = var.db_instance_class
  allocated_storage     = var.db_allocated_storage
  database_name         = var.db_name
  database_username     = var.db_username
  database_password     = var.db_password
  multi_az              = var.enable_multi_az
  backup_retention_period = var.db_backup_retention_days
  skip_final_snapshot   = var.environment != "production"
}

# Cache Module (ElastiCache Redis)
module "cache" {
  source = "./modules/cache"
  count  = var.deployment_mode == "production" ? 1 : 0

  project_name       = var.project_name
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_id  = module.security.redis_security_group_id
  node_type          = var.redis_node_type
  num_cache_nodes    = var.redis_num_replicas + 1
  engine_version     = var.redis_engine_version
}

# Compute Module (EC2, ASG, ALB)
module "compute" {
  source = "./modules/compute"

  project_name            = var.project_name
  deployment_mode         = var.deployment_mode
  vpc_id                  = module.vpc.vpc_id
  public_subnet_ids       = module.vpc.public_subnet_ids
  private_subnet_ids      = module.vpc.private_subnet_ids
  ec2_security_group_id   = module.security.ec2_security_group_id
  alb_security_group_id   = module.security.alb_security_group_id
  iam_instance_profile    = module.security.ec2_instance_profile_name
  ami_id                  = data.aws_ami.ubuntu.id
  instance_type           = var.instance_type
  key_name                = var.ssh_key_name
  domain_name             = var.domain_name
  admin_email             = var.admin_email
  smtp_address            = var.smtp_address
  smtp_port               = var.smtp_port
  smtp_username           = var.smtp_username
  smtp_password           = var.smtp_password
  s3_bucket_name          = module.storage.bucket_name
  s3_region               = var.aws_region

  # External database and cache (if production mode)
  db_host                 = var.deployment_mode == "production" ? module.database[0].endpoint : ""
  db_name                 = var.deployment_mode == "production" ? var.db_name : ""
  db_username             = var.deployment_mode == "production" ? var.db_username : ""
  db_password             = var.deployment_mode == "production" ? var.db_password : ""
  redis_host              = var.deployment_mode == "production" ? module.cache[0].endpoint : ""

  # Auto Scaling
  min_size                = var.asg_min_size
  max_size                = var.asg_max_size
  desired_capacity        = var.asg_desired_capacity
}

# Route 53 (Optional)
resource "aws_route53_record" "discourse" {
  count   = var.create_route53_record ? 1 : 0
  zone_id = var.route53_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = var.deployment_mode == "production" ? module.compute.alb_dns_name : ""
    zone_id                = var.deployment_mode == "production" ? module.compute.alb_zone_id : ""
    evaluate_target_health = true
  }
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "ec2_cpu" {
  alarm_name          = "${var.project_name}-ec2-cpu-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors ec2 cpu utilization"
  alarm_actions       = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []

  dimensions = {
    AutoScalingGroupName = var.deployment_mode == "production" ? module.compute.asg_name : ""
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  count               = var.deployment_mode == "production" ? 1 : 0
  alarm_name          = "${var.project_name}-rds-cpu-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors rds cpu utilization"
  alarm_actions       = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []

  dimensions = {
    DBInstanceIdentifier = module.database[0].db_instance_id
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_storage" {
  count               = var.deployment_mode == "production" ? 1 : 0
  alarm_name          = "${var.project_name}-rds-free-storage"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "10000000000" # 10GB in bytes
  alarm_description   = "This metric monitors rds free storage space"
  alarm_actions       = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []

  dimensions = {
    DBInstanceIdentifier = module.database[0].db_instance_id
  }
}
