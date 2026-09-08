variable "project" {
  description = "Nombre del proyecto (prefijo de recursos)."
  type        = string
  default     = "freshbox"
}

variable "environment" {
  description = "Nombre del entorno (dev/staging/prod)."
  type        = string
  default     = "dev"
}

variable "bucket_name" {
  description = "Nombre del bucket S3 para el state. Si está vacío se genera automáticamente con un sufijo único."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags aplicados a los recursos del bootstrap."
  type        = map(string)
  default = {
    Project     = "freshbox"
    ManagedBy   = "terraform"
    Environment = "dev"
  }
}
