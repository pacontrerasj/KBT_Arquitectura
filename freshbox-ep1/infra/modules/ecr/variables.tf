variable "project" {
  description = "Nombre del proyecto (prefijo de recursos)."
  type        = string
  default     = "freshbox"
}

variable "repository_names" {
  description = <<-EOT
    Nombres de los 5 repositorios ECR. Ejemplo:
    ["freshbox-frontend", "freshbox-get-products", ...]
  EOT
  type        = list(string)
  validation {
    condition     = length(var.repository_names) > 0
    error_message = "Se debe indicar al menos un nombre de repositorio."
  }
}

variable "image_tag_mutability" {
  description = <<-EOT
    MUTABLE permite sobrescribir tags (ej. `latest`); IMMUTABLE evita que un tag
    apuntado por un despliegue sea sobrescrito accidentalmente.
    Se usa IMMUTABLE porque el pipeline taggea con SHA de commit + latest.
  EOT
  type        = string
  default     = "IMMUTABLE"
  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.image_tag_mutability)
    error_message = "image_tag_mutability debe ser MUTABLE o IMMUTABLE."
  }
}

variable "scan_on_push" {
  description = "Activa el escaneo automatizado de vulnerabilidades en el push de imágenes."
  type        = bool
  default     = true
}

variable "max_image_count" {
  description = "Número máximo de imágenes a mantener por repositorio (lifecycle policy)."
  type        = number
  default     = 5
  validation {
    condition     = var.max_image_count > 0
    error_message = "max_image_count debe ser mayor a 0."
  }
}

variable "force_delete" {
  description = "Permite borrar el repositorio aunque contenga imágenes (útil en demo/limpieza)."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags aplicados a los repositorios ECR."
  type        = map(string)
  default     = {}
}
