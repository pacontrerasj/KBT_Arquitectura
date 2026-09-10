output "alb_dns_name" {
  description = "DNS del ALB (ingresar en navegador para probar)."
  value       = aws_lb.main.dns_name
}

output "alb_arn" {
  description = "ARN del ALB."
  value       = aws_lb.main.arn
}

output "alb_zone_id" {
  description = "Zone ID del ALB (para registros Route53 alias)."
  value       = aws_lb.main.zone_id
}

output "target_group_arn" {
  description = "ARN del Target Group de la capa APP."
  value       = aws_lb_target_group.app.arn
}

output "listener_http_arn" {
  description = "ARN del listener HTTP."
  value       = aws_lb_listener.http.arn
}
