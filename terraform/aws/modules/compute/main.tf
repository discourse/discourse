# User data script for EC2 instance
locals {
  user_data = templatefile("${path.module}/../../scripts/user-data.sh", {
    domain_name   = var.domain_name
    admin_email   = var.admin_email
    smtp_address  = var.smtp_address
    smtp_port     = var.smtp_port
    smtp_username = var.smtp_username
    smtp_password = var.smtp_password
    s3_bucket     = var.s3_bucket_name
    s3_region     = var.s3_region
    db_host       = var.db_host
    db_name       = var.db_name
    db_username   = var.db_username
    db_password   = var.db_password
    redis_host    = var.redis_host
    deployment_mode = var.deployment_mode
  })
}

# Elastic IP (Simple mode only)
resource "aws_eip" "discourse" {
  count  = var.deployment_mode == "simple" ? 1 : 0
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-eip"
  }
}

# EC2 Instance (Simple mode only)
resource "aws_instance" "discourse" {
  count = var.deployment_mode == "simple" ? 1 : 0

  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = var.public_subnet_ids[0]
  vpc_security_group_ids = [var.ec2_security_group_id]
  iam_instance_profile   = var.iam_instance_profile

  user_data = local.user_data

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 30
    encrypted             = true
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  monitoring = true

  tags = {
    Name = "${var.project_name}-instance"
  }

  lifecycle {
    ignore_changes = [
      ami,
      user_data
    ]
  }
}

# Associate Elastic IP (Simple mode only)
resource "aws_eip_association" "discourse" {
  count       = var.deployment_mode == "simple" ? 1 : 0
  instance_id = aws_instance.discourse[0].id
  allocation_id = aws_eip.discourse[0].id
}

# Launch Template (Production mode only)
resource "aws_launch_template" "discourse" {
  count = var.deployment_mode == "production" ? 1 : 0

  name_prefix   = "${var.project_name}-lt-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  iam_instance_profile {
    name = var.iam_instance_profile
  }

  vpc_security_group_ids = [var.ec2_security_group_id]

  user_data = base64encode(local.user_data)

  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_type           = "gp3"
      volume_size           = 30
      encrypted             = true
      delete_on_termination = true
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  monitoring {
    enabled = true
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "${var.project_name}-instance"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Application Load Balancer (Production mode only)
resource "aws_lb" "discourse" {
  count = var.deployment_mode == "production" ? 1 : 0

  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = false
  enable_http2              = true
  enable_cross_zone_load_balancing = true

  tags = {
    Name = "${var.project_name}-alb"
  }
}

# Target Group (Production mode only)
resource "aws_lb_target_group" "discourse" {
  count = var.deployment_mode == "production" ? 1 : 0

  name_prefix = "${substr(var.project_name, 0, 6)}-"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/srv/status"
    protocol            = "HTTP"
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = {
    Name = "${var.project_name}-tg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# HTTP Listener (Production mode only)
resource "aws_lb_listener" "http" {
  count = var.deployment_mode == "production" ? 1 : 0

  load_balancer_arn = aws_lb.discourse[0].arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# HTTPS Listener (Production mode only)
# Note: This requires an ACM certificate - configure manually or via Route 53
resource "aws_lb_listener" "https" {
  count = var.deployment_mode == "production" ? 1 : 0

  load_balancer_arn = aws_lb.discourse[0].arn
  port              = "443"
  protocol          = "HTTP" # Initially HTTP, switch to HTTPS after configuring certificate

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.discourse[0].arn
  }

  lifecycle {
    ignore_changes = [
      protocol,
      certificate_arn,
      default_action
    ]
  }
}

# Auto Scaling Group (Production mode only)
resource "aws_autoscaling_group" "discourse" {
  count = var.deployment_mode == "production" ? 1 : 0

  name_prefix         = "${var.project_name}-asg-"
  vpc_zone_identifier = var.private_subnet_ids
  target_group_arns   = [aws_lb_target_group.discourse[0].arn]

  min_size         = var.min_size
  max_size         = var.max_size
  desired_capacity = var.desired_capacity

  health_check_type         = "ELB"
  health_check_grace_period = 300
  default_cooldown          = 300

  launch_template {
    id      = aws_launch_template.discourse[0].id
    version = "$Latest"
  }

  enabled_metrics = [
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupMaxSize",
    "GroupMinSize",
    "GroupPendingInstances",
    "GroupStandbyInstances",
    "GroupTerminatingInstances",
    "GroupTotalInstances"
  ]

  tag {
    key                 = "Name"
    value               = "${var.project_name}-asg-instance"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      desired_capacity
    ]
  }
}

# Auto Scaling Policy - Target Tracking (Production mode only)
resource "aws_autoscaling_policy" "cpu_target_tracking" {
  count = var.deployment_mode == "production" ? 1 : 0

  name                   = "${var.project_name}-cpu-target-tracking"
  autoscaling_group_name = aws_autoscaling_group.discourse[0].name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 70.0
  }
}

# Auto Scaling Policy - Scale Up (Production mode only)
resource "aws_autoscaling_policy" "scale_up" {
  count = var.deployment_mode == "production" ? 1 : 0

  name                   = "${var.project_name}-scale-up"
  autoscaling_group_name = aws_autoscaling_group.discourse[0].name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 300
}

# Auto Scaling Policy - Scale Down (Production mode only)
resource "aws_autoscaling_policy" "scale_down" {
  count = var.deployment_mode == "production" ? 1 : 0

  name                   = "${var.project_name}-scale-down"
  autoscaling_group_name = aws_autoscaling_group.discourse[0].name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 300
}
