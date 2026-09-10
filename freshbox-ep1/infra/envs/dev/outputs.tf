# ─── Outputs del entorno DEV ──────────────────────────────────────

# ── Red ──────────────────────────────────────────────────────────

output "vpc_id" {
  description = "ID de la VPC."
  value       = module.network.vpc_id
}

output "public_subnet_ids" {
  description = "IDs de las subredes públicas."
  value       = module.network.public_subnet_ids
}

output "app_subnet_ids" {
  description = "IDs de las subredes privadas APP."
  value       = module.network.app_subnet_ids
}

output "data_subnet_ids" {
  description = "IDs de las subredes privadas DATA."
  value       = module.network.data_subnet_ids
}

# ── ECR ──────────────────────────────────────────────────────────

output "ecr_repository_urls" {
  description = "URLs de los repositorios ECR."
  value       = module.ecr.repository_urls
}

# ── ALB ──────────────────────────────────────────────────────────

output "alb_dns_name" {
  description = "DNS del Application Load Balancer."
  value       = module.alb.alb_dns_name
}

output "alb_arn" {
  description = "ARN del ALB."
  value       = module.alb.alb_arn
}

# ── Compute ──────────────────────────────────────────────────────

output "app_asg_name" {
  description = "Nombre del Auto Scaling Group."
  value       = module.compute_app.asg_name
}

output "mysql_private_ip" {
  description = "IP privada de la instancia MySQL."
  value       = module.compute_data.private_ip
}

output "mysql_instance_id" {
  description = "ID de la instancia MySQL."
  value       = module.compute_data.instance_id
}

# ── Backup ───────────────────────────────────────────────────────

output "backup_vault_arn" {
  description = "ARN del Backup Vault."
  value       = module.backup.vault_arn
}

output "backup_plan_id" {
  description = "ID del Backup Plan."
  value       = module.backup.plan_id
}
