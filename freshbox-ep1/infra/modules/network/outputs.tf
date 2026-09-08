output "vpc_id" {
  description = "ID de la VPC."
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR de la VPC."
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "IDs de las subredes públicas."
  value       = { for k, s in aws_subnet.public : k => s.id }
}

output "public_subnet_cidrs" {
  description = "CIDRs de las subredes públicas."
  value       = { for k, s in aws_subnet.public : k => s.cidr_block }
}

output "app_subnet_ids" {
  description = "IDs de las subredes privadas APP."
  value       = { for k, s in aws_subnet.app : k => s.id }
}

output "data_subnet_ids" {
  description = "IDs de las subredes privadas DATA."
  value       = { for k, s in aws_subnet.data : k => s.id }
}

output "nat_gateway_id" {
  description = "ID del NAT Gateway."
  value       = aws_nat_gateway.main.id
}

output "internet_gateway_id" {
  description = "ID del Internet Gateway."
  value       = aws_internet_gateway.main.id
}
