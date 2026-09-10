# ─── FreshBox SpA – Entorno DEV ───────────────────────────────────
# Orquesta todos los módulos para desplegar la infraestructura completa.

# ── 1. Red ────────────────────────────────────────────────────────
module "network" {
  source = "../../modules/network"

  project  = var.project
  vpc_cidr = var.vpc_cidr
  azs      = var.azs
  nat_az   = var.azs[0]
  tags     = local.common_tags
}

# ── 2. Seguridad ──────────────────────────────────────────────────
module "security" {
  source = "../../modules/security"

  project = var.project
  vpc_id  = module.network.vpc_id
  tags    = local.common_tags
}

# ── 3. ECR ────────────────────────────────────────────────────────
# image_tag_mutability = MUTABLE permite que el pipeline sobrescriba `latest`
# en cada build (necesario para deploys repetidos en un entorno académico).
module "ecr" {
  source = "../../modules/ecr"

  project               = var.project
  repository_names      = var.ecr_repository_names
  image_tag_mutability  = "MUTABLE"
  tags                  = local.common_tags
}

# ── 4. ALB ────────────────────────────────────────────────────────
module "alb" {
  source = "../../modules/alb"

  project           = var.project
  vpc_id            = module.network.vpc_id
  public_subnet_ids = values(module.network.public_subnet_ids)
  alb_sg_id         = module.security.alb_sg_id
  app_sg_id         = module.security.app_sg_id
  health_check_path = var.health_check_path
  tags              = local.common_tags
}

# ── 5. Compute DATA (MySQL) ──────────────────────────────────────
# Se crea primero para obtener la IP privada que necesitan las APP.
module "compute_data" {
  source = "../../modules/compute-data"

  project                   = var.project
  environment               = var.environment
  data_subnet_id            = module.network.data_subnet_ids[var.azs[0]]
  data_sg_id                = module.security.data_sg_id
  instance_type             = var.db_instance_type
  iam_instance_profile_name = var.iam_instance_profile_name
  volume_size               = var.db_volume_size
  db_name                   = var.db_name
  db_user                   = var.db_user
  db_pass                   = var.db_pass
  db_root_pass              = var.db_root_pass
  assign_eip                = var.assign_eip
  tags                      = local.common_tags
}

# ── 6. Compute APP (ASG + Launch Template) ───────────────────────
module "compute_app" {
  source = "../../modules/compute-app"

  project                   = var.project
  environment               = var.environment
  app_subnet_ids            = [for az in var.azs : module.network.app_subnet_ids[az]]
  app_sg_id                 = module.security.app_sg_id
  target_group_arns         = [module.alb.target_group_arn]
  instance_type             = var.app_instance_type
  iam_instance_profile_name = var.iam_instance_profile_name
  min_size                  = var.app_min_size
  max_size                  = var.app_max_size
  desired_capacity          = var.app_desired_capacity
  volume_size               = var.app_volume_size
  db_host                   = module.compute_data.private_ip
  db_user                   = var.db_user
  db_pass                   = var.db_pass
  db_name                   = var.db_name
  enable_scaling            = var.enable_scaling
  tags                      = local.common_tags
}

# ── 7. Backup / DR (opcional; el Learner Lab no permite crear IAM) ─
# Deshabilitar con enable_backup = false si el entorno no permite iam:CreateRole.
module "backup" {
  count = var.enable_backup ? 1 : 0

  source = "../../modules/backup"

  project               = var.project
  environment           = var.environment
  backup_instance_tag   = "Backup"
  backup_instance_value = "true"
  retention_days        = var.backup_retention_days
  tags                  = local.common_tags
}
