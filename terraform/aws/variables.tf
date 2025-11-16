variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "discourse"
}

variable "environment" {
  description = "Environment (dev, staging, production)"
  type        = string
  default     = "production"
}

variable "deployment_mode" {
  description = "Deployment mode: simple (single EC2) or production (ASG, ALB, RDS, ElastiCache)"
  type        = string
  default     = "simple"

  validation {
    condition     = contains(["simple", "production"], var.deployment_mode)
    error_message = "deployment_mode must be either 'simple' or 'production'"
  }
}

# Networking
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "allowed_ssh_cidr" {
  description = "CIDR blocks allowed to SSH into instances"
  type        = list(string)
  default     = ["0.0.0.0/0"] # WARNING: Restrict this in production!
}

# Domain Configuration
variable "domain_name" {
  description = "Domain name for Discourse (e.g., discourse.example.com)"
  type        = string
}

variable "admin_email" {
  description = "Admin email address"
  type        = string
}

# Route 53
variable "create_route53_record" {
  description = "Whether to create Route 53 DNS record"
  type        = bool
  default     = false
}

variable "route53_zone_id" {
  description = "Route 53 hosted zone ID (required if create_route53_record is true)"
  type        = string
  default     = ""
}

# EC2 Configuration
variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.small"
}

variable "ssh_key_name" {
  description = "Name of AWS key pair for SSH access"
  type        = string
}

# Email Configuration (SMTP)
variable "smtp_address" {
  description = "SMTP server address (e.g., email-smtp.us-east-1.amazonaws.com)"
  type        = string
}

variable "smtp_port" {
  description = "SMTP port"
  type        = number
  default     = 587
}

variable "smtp_username" {
  description = "SMTP username"
  type        = string
  sensitive   = true
}

variable "smtp_password" {
  description = "SMTP password"
  type        = string
  sensitive   = true
}

# Database Configuration (RDS)
variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.small"
}

variable "db_allocated_storage" {
  description = "Allocated storage for RDS in GB"
  type        = number
  default     = 20
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "discourse_production"
}

variable "db_username" {
  description = "Database username"
  type        = string
  default     = "discourse"
}

variable "db_password" {
  description = "Database password (randomly generated if not provided)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "enable_multi_az" {
  description = "Enable Multi-AZ for RDS"
  type        = bool
  default     = false
}

variable "db_backup_retention_days" {
  description = "Number of days to retain RDS backups"
  type        = number
  default     = 7
}

# Redis Configuration (ElastiCache)
variable "redis_node_type" {
  description = "ElastiCache Redis node type"
  type        = string
  default     = "cache.t3.small"
}

variable "redis_num_replicas" {
  description = "Number of Redis replica nodes"
  type        = number
  default     = 0
}

variable "redis_engine_version" {
  description = "Redis engine version"
  type        = string
  default     = "7.0"
}

# Auto Scaling
variable "asg_min_size" {
  description = "Minimum number of instances in ASG"
  type        = number
  default     = 1
}

variable "asg_max_size" {
  description = "Maximum number of instances in ASG"
  type        = number
  default     = 4
}

variable "asg_desired_capacity" {
  description = "Desired number of instances in ASG"
  type        = number
  default     = 2
}

# Storage
variable "enable_s3_versioning" {
  description = "Enable versioning for S3 bucket"
  type        = bool
  default     = true
}

# Monitoring
variable "sns_topic_arn" {
  description = "SNS topic ARN for CloudWatch alarms"
  type        = string
  default     = ""
}
