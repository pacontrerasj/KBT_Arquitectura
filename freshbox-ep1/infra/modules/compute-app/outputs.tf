output "asg_name" {
  description = "Nombre del Auto Scaling Group de la capa APP."
  value       = aws_autoscaling_group.app.name
}

output "asg_id" {
  description = "ID del Auto Scaling Group."
  value       = aws_autoscaling_group.app.id
}

output "launch_template_id" {
  description = "ID del Launch Template."
  value       = aws_launch_template.app.id
}

output "launch_template_latest_version" {
  description = "Última versión del Launch Template."
  value       = aws_launch_template.app.latest_version
}
