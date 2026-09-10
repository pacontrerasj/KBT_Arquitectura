variable "project" {
  description = "Nombre del proyecto (prefijo de recursos)."
  type        = string
  default     = "freshbox"
}

variable "vpc_id" {
  description = "ID de la VPC."
  type        = string
}

variable "public_subnet_ids" {
  description = "Lista de IDs de subredes públicas para el ALB."
  type        = list(string)
}

variable "alb_sg_id" {
  description = "ID del Security Group del ALB."
  type        = string
}

variable "app_sg_id" {
  description = "ID del Security Group de la capa APP."
  type        = string
}

variable "health_check_path" {
  description = "Ruta del health check."
  type        = string
  default     = "/"
}

variable "tags" {
  description = "Tags aplicados a los recursos del ALB."
  type        = map(string)
  default     = {}
}
