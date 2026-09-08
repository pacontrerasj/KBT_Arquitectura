variable "project" {
  description = "Nombre del proyecto (prefijo de recursos)."
  type        = string
  default     = "freshbox"
}

variable "vpc_cidr" {
  description = "CIDR de la VPC."
  type        = string
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr debe ser un bloque CIDR válido."
  }
}

variable "azs" {
  description = "Zonas de disponibilidad a utilizar (exactamente 2)."
  type        = list(string)
  validation {
    condition     = length(var.azs) == 2
    error_message = "Se requieren exactamente 2 zonas de disponibilidad (AZ1a/AZ1b)."
  }
}

variable "nat_az" {
  description = "AZ donde se coloca el NAT Gateway (subred pública de esa AZ)."
  type        = string
}

variable "tags" {
  description = "Tags aplicados a los recursos de red."
  type        = map(string)
  default     = {}
}
