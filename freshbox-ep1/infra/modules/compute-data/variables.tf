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

variable "data_subnet_id" {
  description = "ID de la subred privada DATA."
  type        = string
}

variable "data_sg_id" {
  description = "ID del Security Group de la capa DATA."
  type        = string
}

variable "instance_type" {
  description = "Tipo de instancia (ARM Graviton)."
  type        = string
  default     = "t4g.small"
}

variable "ami_id" {
  description = "AMI opcional para la instancia MySQL."
  type        = string
  default     = ""
}

variable "iam_instance_profile_name" {
  description = "Nombre del IAM Instance Profile (LabRole de AWS Academy)."
  type        = string
}

variable "volume_size" {
  description = "Tamaño del volumen EBS (GB)."
  type        = number
  default     = 20
}

variable "ebs_encrypted" {
  description = "Cifra el volumen EBS de la instancia MySQL."
  type        = bool
  default     = true
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
  description = "Asigna una EIP a la instancia DATA (opcional; puede no estar disponible en Learner Lab)."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags aplicados a la instancia MySQL."
  type        = map(string)
  default     = {}
}
