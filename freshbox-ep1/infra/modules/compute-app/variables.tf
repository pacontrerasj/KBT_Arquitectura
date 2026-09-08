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

variable "app_subnet_ids" {
  description = "Lista de IDs de subredes privadas APP."
  type        = list(string)
}

variable "app_sg_id" {
  description = "ID del Security Group de la capa APP."
  type        = string
}

variable "target_group_arns" {
  description = "Lista de ARNs de target groups del ALB a los que se registra el ASG."
  type        = list(string)
  default     = []
}

variable "instance_type" {
  description = "Tipo de instancia (ARM Graviton)."
  type        = string
  default     = "t4g.small"
}

variable "ami_id" {
  description = "AMI opcional. Si está vacío se usa la última Amazon Linux 2023 ARM."
  type        = string
  default     = ""
}

variable "iam_instance_profile_name" {
  description = "Nombre del IAM Instance Profile (LabRole de AWS Academy). No se crea el rol."
  type        = string
}

variable "min_size" {
  description = "Tamaño mínimo del ASG."
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Tamaño máximo del ASG."
  type        = number
  default     = 4
}

variable "desired_capacity" {
  description = "Capacidad deseada inicial del ASG."
  type        = number
  default     = 2
}

variable "volume_size" {
  description = "Tamaño del volumen EBS raíz (GB)."
  type        = number
  default     = 20
}

variable "ebs_encrypted" {
  description = "Cifra el volumen EBS raíz."
  type        = bool
  default     = true
}

variable "enable_scaling" {
  description = "Habilita políticas de escalado automático por CPU."
  type        = bool
  default     = true
}

variable "db_host" {
  description = "Host de MySQL (IP privada de la EC2 MySQL)."
  type        = string
}

variable "db_user" {
  description = "Usuario de MySQL."
  type        = string
  default     = "alumno"
}

variable "db_pass" {
  description = "Password de MySQL, inyectado solo en user data (no en código)."
  type        = string
  sensitive   = true
  default     = ""
}

variable "db_name" {
  description = "Nombre de la base de datos."
  type        = string
  default     = "freshbox"
}

variable "tags" {
  description = "Tags aplicados a los recursos de cómputo APP."
  type        = map(string)
  default     = {}
}
