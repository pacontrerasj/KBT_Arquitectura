terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ── Backup Vault ─────────────────────────────────────────────────

resource "aws_backup_vault" "main" {
  name = "${var.project}-vault-${var.environment}"
  tags = merge(var.tags, { Name = "${var.project}-vault" })
}

# ── IAM Role para AWS Backup ────────────────────────────────────

data "aws_iam_policy_document" "backup_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "backup" {
  name               = "${var.project}-backup-role-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.backup_assume_role.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "backup" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

# ── Backup Plan (diario, retención configurable) ────────────────

resource "aws_backup_plan" "main" {
  name = "${var.project}-plan-${var.environment}"

  rule {
    rule_name         = "daily-backup"
    target_vault_name = aws_backup_vault.main.name
    schedule          = "cron(0 2 * * ? *)"

    lifecycle {
      delete_after = var.retention_days
    }
  }

  tags = merge(var.tags, { Name = "${var.project}-backup-plan" })
}

# ── Selección de recursos (por tag) ─────────────────────────────

resource "aws_backup_selection" "ec2" {
  name         = "${var.project}-ec2-selection-${var.environment}"
  plan_id      = aws_backup_plan.main.id
  iam_role_arn = aws_iam_role.backup.arn

  resources = ["arn:aws:ec2:*:*:instance/*"]

  condition {
    string_equals {
      key   = "aws:ResourceTag/${var.backup_instance_tag}"
      value = var.backup_instance_value
    }
  }
}
