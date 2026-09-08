terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_security_group" "alb" {
  name        = "${var.project}-sg-alb"
  description = "Ingreso público 80/443 hacia el ALB."
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = "${var.project}-sg-alb" })
}

resource "aws_vpc_security_group_ingress_rule" "alb_80" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  description       = "HTTP desde internet"
}

resource "aws_vpc_security_group_ingress_rule" "alb_443" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "HTTPS desde internet"
}

resource "aws_vpc_security_group_egress_rule" "alb_egress" {
  security_group_id            = aws_security_group.alb.id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.app.id
  description                  = "Salida hacia las instancias de aplicación"
}

resource "aws_security_group" "app" {
  name        = "${var.project}-sg-app"
  description = "Ingreso 80 y 3001-3004 desde SG-ALB."
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = "${var.project}-sg-app" })
}

resource "aws_vpc_security_group_ingress_rule" "app_http" {
  security_group_id            = aws_security_group.app.id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.alb.id
  description                  = "HTTP desde ALB"
}

resource "aws_vpc_security_group_ingress_rule" "app_services" {
  security_group_id            = aws_security_group.app.id
  from_port                    = 3001
  to_port                      = 3004
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.alb.id
  description                  = "Microservicios 3001-3004 desde ALB"
}

resource "aws_vpc_security_group_ingress_rule" "app_ssm_mgmt" {
  security_group_id = aws_security_group.app.id
  cidr_ipv4         = "10.0.0.0/16"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "SSM/SSM Session Manager de gestión (rango de VPC)"
}

resource "aws_vpc_security_group_egress_rule" "app_egress" {
  security_group_id = aws_security_group.app.id
  from_port         = 3306
  to_port           = 3306
  ip_protocol       = "tcp"
  referenced_security_group_id = aws_security_group.data.id
  description                  = "Salida MySQL hacia la capa de datos"
}

resource "aws_security_group" "data" {
  name        = "${var.project}-sg-data"
  description = "Ingreso 3306 desde SG-APP."
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = "${var.project}-sg-data" })
}

resource "aws_vpc_security_group_ingress_rule" "data_mysql" {
  security_group_id            = aws_security_group.data.id
  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.app.id
  description                  = "MySQL desde capa APP"
}

resource "aws_vpc_security_group_egress_rule" "data_egress" {
  security_group_id = aws_security_group.data.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Salida completa (instalación y backup)"
}
