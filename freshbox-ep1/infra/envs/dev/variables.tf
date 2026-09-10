# ─── Parámetros del entorno DEV ───────────────────────────────────

variable "project" {
  description = "Nombre del proyecto (prefijo de recursos)."
  type        = string
  default     = "freshbox"
}

variable "environment" {
  description = "Nombre del entorno."
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "Región de AWS."
  type        = string
  default     = "us-east-1"
}

# ── Red ──────────────────────────────────────────────────────────

variable "vpc_cidr" {
  description = "CIDR de la VPC."
  type        = string
  default     = "10.0.0.0/22"
}

variable "azs" {
  description = "Zonas de disponibilidad (exactamente 2)."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

# ── ECR ──────────────────────────────────────────────────────────

variable "ecr_repository_names" {
  description = "Nombres de los 5 repositorios ECR."
  type        = list(string)
  default = [
    "freshbox-frontend",
    "freshbox-get-products",
    "freshbox-create-product",
    "freshbox-update-product",
    "freshbox-delete-product"
  ]
}

# ── ALB ──────────────────────────────────────────────────────────

variable "health_check_path" {
  description = "Ruta del health check del ALB."
  type        = string
  default     = "/"
}

# ── Compute APP ──────────────────────────────────────────────────

variable "app_instance_type" {
  description = "Tipo de instancia para la capa APP."
  type        = string
  default     = "t4g.small"
}

variable "app_min_size" {
  description = "Tamaño mínimo del ASG."
  type        = number
  default     = 2
}

variable "app_max_size" {
  description = "Tamaño máximo del ASG."
  type        = number
  default     = 4
}

variable "app_desired_capacity" {
  description = "Capacidad deseada del ASG."
  type        = number
  default     = 2
}

variable "app_volume_size" {
  description = "Tamaño del volumen EBS de las APP (GB)."
  type        = number
  default     = 20
}

variable "enable_scaling" {
  description = "Habilita escalado automático por CPU."
  type        = bool
  default     = true
}

# ── Compute DATA (MySQL) ─────────────────────────────────────────

variable "db_instance_type" {
  description = "Tipo de instancia para MySQL."
  type        = string
  default     = "t4g.small"
}

variable "db_volume_size" {
  description = "Tamaño del volumen EBS de MySQL (GB)."
  type        = number
  default     = 20
}

variable "db_name" {
  description = "Nombre de la base de datos."
  type        = string
  default     = "freshbox"
}

variable "db_user" {
  description = "Usuario de aplicación de MySQL."
  type        = string
  default     = "alumno"
}

variable "db_pass" {
  description = "Password del usuario de aplicación."
  type        = string
  sensitive   = true
  default     = ""
}

variable "db_root_pass" {
  description = "Password de root de MySQL."
  type        = string
  sensitive   = true
  default     = ""
}

variable "assign_eip" {
  description = "Asigna EIP a la instancia MySQL (puede no estar disponible en Learner Lab)."
  type        = bool
  default     = false
}

# ── IAM ──────────────────────────────────────────────────────────

variable "iam_instance_profile_name" {
  description = "Nombre del Instance Profile IAM (LabRole de AWS Academy)."
  type        = string
  default     = "LabInstanceProfile"
}

# ── Backup ───────────────────────────────────────────────────────

variable "backup_retention_days" {
  description = "Días de retención de backups."
  type        = number
  default     = 7
}

# ── Locals ───────────────────────────────────────────────────────

locals {
  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
