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

resource "aws_instance" "mysql" {
  ami                    = coalesce(var.ami_id, data.aws_ami.amazon_linux_2023.id)
  instance_type          = var.instance_type
  subnet_id              = var.data_subnet_id
  vpc_security_group_ids = [var.data_sg_id]
  iam_instance_profile   = var.iam_instance_profile_name

  user_data = base64encode(templatefile("${path.module}/user-data-mysql.sh", {
    db_name      = var.db_name
    db_user      = var.db_user
    db_pass      = var.db_pass
    db_root_pass = var.db_root_pass
  }))

  root_block_device {
    volume_size           = var.volume_size
    volume_type           = "gp3"
    encrypted             = var.ebs_encrypted
    delete_on_termination = true
  }

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = merge(var.tags, {
    Name   = "${var.project}-mysql-${var.environment}"
    Tier   = "data"
    Backup = "true"
  })

  lifecycle {
    ignore_changes = [ami]
  }
}

# EIP opcional para la EC2 DATA (se documenta; puede no estar disponible en Learner Lab)
resource "aws_eip" "mysql_primary" {
  count = var.assign_eip ? 1 : 0
  domain = "vpc"

  instance = aws_instance.mysql.id

  tags = merge(var.tags, { Name = "${var.project}-mysql-eip" })
}
