output "state_bucket" {
  description = "Nombre del bucket S3 que almacena el estado remoto."
  value       = aws_s3_bucket.state.id
}

output "state_bucket_arn" {
  description = "ARN del bucket S3 de estado."
  value       = aws_s3_bucket.state.arn
}

output "lock_table" {
  description = "Nombre de la tabla DynamoDB usada para el locking del estado."
  value       = aws_dynamodb_table.state_lock.id
}

output "lock_table_arn" {
  description = "ARN de la tabla DynamoDB de locking."
  value       = aws_dynamodb_table.state_lock.arn
}
