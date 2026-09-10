terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-arm64"]
  }

  filter {
    name   = "architecture"
    values = ["arm64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
}

# Launch Template para las instancias de aplicación
resource "aws_launch_template" "app" {
  name_prefix   = "${var.project}-app-lt-"
  image_id      = coalesce(var.ami_id, data.aws_ami.amazon_linux_2023.id)
  instance_type = var.instance_type

  vpc_security_group_ids = [var.app_sg_id]

  user_data = base64encode(templatefile("${path.module}/user-data-app.sh", {
    account_id = local.account_id
    region     = local.region
    project    = var.project
    db_host    = var.db_host
    db_user    = var.db_user
    db_pass    = var.db_pass
    db_name    = var.db_name
    ecr_repos  = local.repo_names
  }))

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tag_specifications {
    resource_type = "instance"
    tags          = merge(var.tags, { Name = "${var.project}-app-${var.environment}" })
  }

  tag_specifications {
    resource_type = "volume"
    tags          = merge(var.tags, { Name = "${var.project}-app-vol-${var.environment}" })
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = var.volume_size
      volume_type           = "gp3"
      encrypted             = var.ebs_encrypted
      delete_on_termination = true
    }
  }

  # Perfil IAM de instancia (LabRole) — no se crea el rol, solo se referencia
  iam_instance_profile {
    name = var.iam_instance_profile_name
  }

  lifecycle {
    create_before_destroy = true
  }
}

locals {
  repo_names = ["frontend", "get-products", "create-product", "update-product", "delete-product"]
}

# Auto Scaling Group (min 2 / max 4)
resource "aws_autoscaling_group" "app" {
  name                = "${var.project}-app-asg"
  min_size            = var.min_size
  max_size            = var.max_size
  desired_capacity    = var.desired_capacity
  vpc_zone_identifier = var.app_subnet_ids

  target_group_arns = var.target_group_arns

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.project}-app-${var.environment}"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }

  lifecycle {
    ignore_changes = [desired_capacity]
  }
}

# Escalado por CPU opcional
resource "aws_autoscaling_policy" "cpu_scale_out" {
  count = var.enable_scaling ? 1 : 0

  name                   = "${var.project}-cpu-scale-out"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.app.name
}

resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  count = var.enable_scaling ? 1 : 0

  alarm_name          = "${var.project}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 70
  alarm_description   = "Escala out cuando la CPU promedio supera 70%"
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app.name
  }

  alarm_actions = [aws_autoscaling_policy.cpu_scale_out[0].arn]
}
