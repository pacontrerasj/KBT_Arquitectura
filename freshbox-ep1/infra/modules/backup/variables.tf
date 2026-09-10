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

variable "backup_instance_tag" {
  description = "Key del tag para identificar instancias con backup habilitado."
  type        = string
  default     = "Backup"
}

variable "backup_instance_value" {
  description = "Valor del tag para filtrar instancias con backup."
  type        = string
  default     = "true"
}

variable "retention_days" {
  description = "Días de retención de los backups."
  type        = number
  default     = 7
}

variable "tags" {
  description = "Tags aplicados a los recursos de backup."
  type        = map(string)
  default     = {}
}
