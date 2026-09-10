output "vault_arn" {
  description = "ARN del Backup Vault."
  value       = aws_backup_vault.main.arn
}

output "vault_name" {
  description = "Nombre del Backup Vault."
  value       = aws_backup_vault.main.name
}

output "plan_id" {
  description = "ID del Backup Plan."
  value       = aws_backup_plan.main.id
}

output "plan_arn" {
  description = "ARN del Backup Plan."
  value       = aws_backup_plan.main.arn
}

output "role_arn" {
  description = "ARN del IAM Role de Backup."
  value       = aws_iam_role.backup.arn
}
