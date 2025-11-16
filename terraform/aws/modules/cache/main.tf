# ElastiCache Subnet Group
resource "aws_elasticache_subnet_group" "main" {
  name        = "${var.project_name}-redis-subnet"
  description = "Subnet group for Discourse Redis"
  subnet_ids  = var.subnet_ids

  tags = {
    Name = "${var.project_name}-redis-subnet-group"
  }
}

# ElastiCache Parameter Group
resource "aws_elasticache_parameter_group" "redis" {
  name        = "${var.project_name}-redis-params"
  family      = "redis7"
  description = "Custom parameter group for Discourse Redis"

  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru"
  }

  tags = {
    Name = "${var.project_name}-redis-params"
  }
}

# ElastiCache Replication Group (Redis)
resource "aws_elasticache_replication_group" "redis" {
  replication_group_id       = "${var.project_name}-redis"
  description                = "Redis cluster for Discourse"
  engine                     = "redis"
  engine_version             = var.engine_version
  node_type                  = var.node_type
  num_cache_clusters         = var.num_cache_nodes
  port                       = 6379
  parameter_group_name       = aws_elasticache_parameter_group.redis.name
  subnet_group_name          = aws_elasticache_subnet_group.main.name
  security_group_ids         = [var.security_group_id]
  automatic_failover_enabled = var.num_cache_nodes > 1
  multi_az_enabled           = var.num_cache_nodes > 1
  at_rest_encryption_enabled = true
  transit_encryption_enabled = false # Discourse doesn't support TLS for Redis
  snapshot_retention_limit   = 5
  snapshot_window            = "03:00-05:00"
  maintenance_window         = "mon:05:00-mon:07:00"
  auto_minor_version_upgrade = true

  notification_topic_arn = var.sns_topic_arn != "" ? var.sns_topic_arn : null

  tags = {
    Name = "${var.project_name}-redis"
  }
}
