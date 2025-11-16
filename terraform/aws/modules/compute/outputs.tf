output "ec2_instance_id" {
  description = "EC2 instance ID (simple mode)"
  value       = var.deployment_mode == "simple" ? aws_instance.discourse[0].id : null
}

output "ec2_public_ip" {
  description = "EC2 public IP (simple mode)"
  value       = var.deployment_mode == "simple" ? aws_eip.discourse[0].public_ip : null
}

output "ec2_private_ip" {
  description = "EC2 private IP (simple mode)"
  value       = var.deployment_mode == "simple" ? aws_instance.discourse[0].private_ip : null
}

output "alb_dns_name" {
  description = "ALB DNS name (production mode)"
  value       = var.deployment_mode == "production" ? aws_lb.discourse[0].dns_name : null
}

output "alb_zone_id" {
  description = "ALB Zone ID (production mode)"
  value       = var.deployment_mode == "production" ? aws_lb.discourse[0].zone_id : null
}

output "alb_arn" {
  description = "ALB ARN (production mode)"
  value       = var.deployment_mode == "production" ? aws_lb.discourse[0].arn : null
}

output "target_group_arn" {
  description = "Target group ARN (production mode)"
  value       = var.deployment_mode == "production" ? aws_lb_target_group.discourse[0].arn : null
}

output "asg_name" {
  description = "Auto Scaling Group name (production mode)"
  value       = var.deployment_mode == "production" ? aws_autoscaling_group.discourse[0].name : null
}

output "asg_arn" {
  description = "Auto Scaling Group ARN (production mode)"
  value       = var.deployment_mode == "production" ? aws_autoscaling_group.discourse[0].arn : null
}

output "launch_template_id" {
  description = "Launch Template ID (production mode)"
  value       = var.deployment_mode == "production" ? aws_launch_template.discourse[0].id : null
}
