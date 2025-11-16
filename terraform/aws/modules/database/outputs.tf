output "db_instance_id" {
  description = "RDS instance ID"
  value       = aws_db_instance.postgres.id
}

output "endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.postgres.endpoint
}

output "address" {
  description = "RDS instance address"
  value       = aws_db_instance.postgres.address
}

output "port" {
  description = "RDS instance port"
  value       = aws_db_instance.postgres.port
}

output "database_name" {
  description = "Database name"
  value       = aws_db_instance.postgres.db_name
}

output "database_username" {
  description = "Database username"
  value       = aws_db_instance.postgres.username
  sensitive   = true
}

output "database_password" {
  description = "Database password"
  value       = var.database_password != "" ? var.database_password : random_password.db_password[0].result
  sensitive   = true
}

output "arn" {
  description = "RDS instance ARN"
  value       = aws_db_instance.postgres.arn
}
