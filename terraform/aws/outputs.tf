output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "ec2_instance_id" {
  description = "EC2 instance ID (simple mode)"
  value       = var.deployment_mode == "simple" ? module.compute.ec2_instance_id : "N/A (using ASG)"
}

output "ec2_public_ip" {
  description = "EC2 instance public IP (simple mode)"
  value       = var.deployment_mode == "simple" ? module.compute.ec2_public_ip : "N/A (using ALB)"
}

output "alb_dns_name" {
  description = "Application Load Balancer DNS name (production mode)"
  value       = var.deployment_mode == "production" ? module.compute.alb_dns_name : "N/A (simple mode)"
}

output "asg_name" {
  description = "Auto Scaling Group name (production mode)"
  value       = var.deployment_mode == "production" ? module.compute.asg_name : "N/A (simple mode)"
}

output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint (production mode)"
  value       = var.deployment_mode == "production" ? module.database[0].endpoint : "N/A (using Docker PostgreSQL)"
}

output "rds_port" {
  description = "RDS PostgreSQL port (production mode)"
  value       = var.deployment_mode == "production" ? module.database[0].port : "N/A"
}

output "redis_endpoint" {
  description = "ElastiCache Redis endpoint (production mode)"
  value       = var.deployment_mode == "production" ? module.cache[0].endpoint : "N/A (using Docker Redis)"
}

output "redis_port" {
  description = "ElastiCache Redis port (production mode)"
  value       = var.deployment_mode == "production" ? module.cache[0].port : "N/A"
}

output "s3_bucket_name" {
  description = "S3 bucket name for uploads"
  value       = module.storage.bucket_name
}

output "s3_bucket_arn" {
  description = "S3 bucket ARN"
  value       = module.storage.bucket_arn
}

output "iam_role_arn" {
  description = "IAM role ARN for EC2 instances"
  value       = module.security.ec2_role_arn
}

output "ssh_command" {
  description = "SSH command to connect to instance (simple mode)"
  value       = var.deployment_mode == "simple" ? "ssh -i ~/.ssh/${var.ssh_key_name}.pem ubuntu@${module.compute.ec2_public_ip}" : "N/A (production mode - use bastion or Systems Manager)"
}

output "discourse_url" {
  description = "Discourse URL"
  value       = "https://${var.domain_name}"
}

output "next_steps" {
  description = "Next steps after deployment"
  value       = <<-EOT

    ============================================
    Discourse Infrastructure Deployed!
    ============================================

    Deployment Mode: ${var.deployment_mode}

    ${var.deployment_mode == "simple" ? "EC2 Instance IP: ${module.compute.ec2_public_ip}" : "ALB DNS: ${module.compute.alb_dns_name}"}
    S3 Bucket: ${module.storage.bucket_name}
    ${var.deployment_mode == "production" ? "RDS Endpoint: ${module.database[0].endpoint}" : ""}
    ${var.deployment_mode == "production" ? "Redis Endpoint: ${module.cache[0].endpoint}" : ""}

    Next Steps:

    1. Configure DNS:
       ${var.deployment_mode == "simple" ? "Create A record: ${var.domain_name} -> ${module.compute.ec2_public_ip}" : "Create CNAME: ${var.domain_name} -> ${module.compute.alb_dns_name}"}

    2. SSH into instance:
       ${var.deployment_mode == "simple" ? "ssh -i ~/.ssh/${var.ssh_key_name}.pem ubuntu@${module.compute.ec2_public_ip}" : "Use AWS Systems Manager Session Manager or bastion host"}

    3. Complete Discourse installation:
       cd /var/discourse
       sudo ./discourse-setup

    ${var.deployment_mode == "production" ? "4. Update app.yml with external services:\n   - DB Host: ${module.database[0].endpoint}\n   - Redis Host: ${module.cache[0].endpoint}\n   - S3 Bucket: ${module.storage.bucket_name}" : ""}

    5. Access Discourse:
       https://${var.domain_name}

    For detailed instructions, see:
    docs/AWS-DEPLOYMENT.md

    ============================================
  EOT
}
