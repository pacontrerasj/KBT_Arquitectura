output "instance_id" {
  description = "ID de la instancia MySQL."
  value       = aws_instance.mysql.id
}

output "private_ip" {
  description = "IP privada de la instancia MySQL (usada como DB_HOST por la capa APP)."
  value       = aws_instance.mysql.private_ip
}

output "availability_zone" {
  description = "AZ donde reside la instancia MySQL (para recuperación cross-AZ)."
  value       = aws_instance.mysql.availability_zone
}

output "security_group_id" {
  description = "ID del Security Group de la capa DATA."
  value       = aws_instance.mysql.vpc_security_group_ids[0]
}
