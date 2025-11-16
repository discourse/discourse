variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "deployment_mode" {
  description = "Deployment mode: simple or production"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "ec2_security_group_id" {
  description = "Security group ID for EC2 instances"
  type        = string
}

variable "alb_security_group_id" {
  description = "Security group ID for ALB"
  type        = string
}

variable "iam_instance_profile" {
  description = "IAM instance profile name"
  type        = string
}

variable "ami_id" {
  description = "AMI ID for EC2 instances"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "key_name" {
  description = "SSH key pair name"
  type        = string
}

variable "domain_name" {
  description = "Domain name for Discourse"
  type        = string
}

variable "admin_email" {
  description = "Admin email address"
  type        = string
}

variable "smtp_address" {
  description = "SMTP server address"
  type        = string
}

variable "smtp_port" {
  description = "SMTP port"
  type        = number
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

variable "s3_bucket_name" {
  description = "S3 bucket name for uploads"
  type        = string
}

variable "s3_region" {
  description = "S3 bucket region"
  type        = string
}

variable "db_host" {
  description = "Database host (empty for Docker PostgreSQL)"
  type        = string
  default     = ""
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = ""
}

variable "db_username" {
  description = "Database username"
  type        = string
  default     = ""
  sensitive   = true
}

variable "db_password" {
  description = "Database password"
  type        = string
  default     = ""
  sensitive   = true
}

variable "redis_host" {
  description = "Redis host (empty for Docker Redis)"
  type        = string
  default     = ""
}

variable "min_size" {
  description = "Minimum instances in ASG"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum instances in ASG"
  type        = number
  default     = 4
}

variable "desired_capacity" {
  description = "Desired instances in ASG"
  type        = number
  default     = 2
}
