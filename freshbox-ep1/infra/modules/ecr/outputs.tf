output "repository_urls" {
  description = "Mapa nombre → URL del repositorio ECR."
  value       = { for name, repo in aws_ecr_repository.repos : name => repo.repository_url }
}

output "repository_names" {
  description = "Lista de nombres de repositorios."
  value       = [for name, repo in aws_ecr_repository.repos : repo.name]
}

output "repository_arns" {
  description = "Mapa nombre → ARN del repositorio ECR."
  value       = { for name, repo in aws_ecr_repository.repos : name => repo.arn }
}
