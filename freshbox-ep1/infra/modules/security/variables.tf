variable "project" {
  description = "Nombre del proyecto (prefijo de recursos)."
  type        = string
  default     = "freshbox"
}

variable "vpc_id" {
  description = "ID de la VPC donde se crean los Security Groups."
  type        = string
}

variable "tags" {
  description = "Tags aplicados a los Security Groups."
  type        = map(string)
  default     = {}
}
