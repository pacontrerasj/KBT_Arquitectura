output "alb_sg_id" {
  description = "ID del Security Group del ALB."
  value       = aws_security_group.alb.id
}

output "app_sg_id" {
  description = "ID del Security Group de la capa APP."
  value       = aws_security_group.app.id
}

output "data_sg_id" {
  description = "ID del Security Group de la capa DATA."
  value       = aws_security_group.data.id
}
