terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

locals {
  # 6 subredes /24 dentro de una VPC /22
  public_subnets  = { for i, az in var.azs : az => cidrsubnet(var.vpc_cidr, 8, i) }
  app_subnets     = { for i, az in var.azs : az => cidrsubnet(var.vpc_cidr, 8, i + 2) }
  data_subnets    = { for i, az in var.azs : az => cidrsubnet(var.vpc_cidr, 8, i + 4) }
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, { Name = "${var.project}-vpc" })
}

# ---------- Subredes Públicas ----------
resource "aws_subnet" "public" {
  for_each                = local.public_subnets
  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value
  availability_zone       = each.key
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name = "${var.project}-public-${each.key}"
    Tier = "public"
  })
}

# ---------- Subredes Privadas APP ----------
resource "aws_subnet" "app" {
  for_each          = local.app_subnets
  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value
  availability_zone = each.key

  tags = merge(var.tags, {
    Name = "${var.project}-app-${each.key}"
    Tier = "app"
  })
}

# ---------- Subredes Privadas DATA ----------
resource "aws_subnet" "data" {
  for_each          = local.data_subnets
  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value
  availability_zone = each.key

  tags = merge(var.tags, {
    Name = "${var.project}-data-${each.key}"
    Tier = "data"
  })
}

# ---------- Internet Gateway ----------
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, { Name = "${var.project}-igw" })
}

# ---------- NAT Gateway (AZ1a) ----------
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = merge(var.tags, { Name = "${var.project}-nat-eip" })
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[var.nat_az].id

  tags = merge(var.tags, { Name = "${var.project}-nat-${var.nat_az}" })
}

# ---------- Route Tables ----------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(var.tags, { Name = "${var.project}-rt-public" })
}

resource "aws_route_table" "private" {
  count  = length(var.azs)
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = merge(var.tags, { Name = "${var.project}-rt-private-${var.azs[count.index]}" })
}

# ---------- Asociaciones ----------
resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "app" {
  for_each       = aws_subnet.app
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[index(var.azs, each.key)].id
}

resource "aws_route_table_association" "data" {
  for_each       = aws_subnet.data
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[index(var.azs, each.key)].id
}
