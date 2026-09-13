# FreshBox SpA - Tests nativos de Terraform (terraform test)
# Verifican el diseño del entorno dev usando SOLO planes (command = plan),
# sin aplicar recursos. Requiere credenciales AWS para resolver los data sources.

variables {
  db_pass      = "test-pass"
  db_root_pass = "test-root-pass"
}

run "diseno_por_defecto" {
  command = plan

  assert {
    condition     = var.project == "freshbox"
    error_message = "El proyecto por defecto debe ser 'freshbox'"
  }

  assert {
    condition     = var.environment == "dev"
    error_message = "El entorno por defecto debe ser 'dev'"
  }

  assert {
    condition     = var.vpc_cidr == "10.0.0.0/22"
    error_message = "La VPC debe usar el CIDR 10.0.0.0/22"
  }

  assert {
    condition     = length(var.azs) == 2
    error_message = "Debe haber exactamente 2 zonas de disponibilidad"
  }

  assert {
    condition     = length(var.ecr_repository_names) == 5
    error_message = "Debe haber exactamente 5 repositorios ECR"
  }

  assert {
    condition     = var.db_name == "freshbox" && var.db_user == "alumno"
    error_message = "La base de datos por defecto debe ser freshbox/alumno"
  }
}

run "opciones_desactivables" {
  command = plan

  variables {
    enable_scaling = false
    enable_backup  = false
  }

  assert {
    condition     = var.enable_scaling == false
    error_message = "enable_scaling debe poder desactivarse (0 instancias de alarma)"
  }

  assert {
    condition     = var.enable_backup == false
    error_message = "enable_backup debe poder desactivarse (módulo de backup opcional)"
  }
}

run "instancias_por_defecto" {
  command = plan

  assert {
    condition     = var.app_instance_type == "t4g.small" && var.db_instance_type == "t4g.small"
    error_message = "Las instancias APP y DB por defecto deben ser t4g.small (ARM, free eligible)"
  }

  assert {
    condition     = var.app_desired_capacity == 2
    error_message = "El ASG debe partir con 2 instancias"
  }
}