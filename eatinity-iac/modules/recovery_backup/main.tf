data "aws_partition" "current" {
  provider = aws.source
}

data "aws_region" "destination" {
  provider = aws.destination
}

locals {
  source_resources = concat(
    [for name in values(var.source_table_names) : "arn:${data.aws_partition.current.partition}:dynamodb:${var.source_region}:${var.account_id}:table/${name}"],
    [for name in values(var.source_bucket_names) : "arn:${data.aws_partition.current.partition}:s3:::${name}"]
  )
}

data "aws_iam_policy_document" "backup_assume_role" {
  provider = aws.source

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
  provider           = aws.source
  name               = "${var.resource_prefix}-aws-backup-role"
  assume_role_policy = data.aws_iam_policy_document.backup_assume_role.json
  tags               = var.tags
}

locals {
  backup_policy_arns = toset([
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup",
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores",
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AWSBackupServiceRolePolicyForS3Backup",
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AWSBackupServiceRolePolicyForS3Restore",
  ])
}

resource "aws_iam_role_policy_attachment" "backup" {
  provider   = aws.source
  for_each   = local.backup_policy_arns
  role       = aws_iam_role.backup.name
  policy_arn = each.value
}

data "aws_iam_policy_document" "operator" {
  provider = aws.source

  statement {
    sid    = "OperateEatinityRecoveryJobs"
    effect = "Allow"
    actions = [
      "backup:DescribeBackupJob",
      "backup:DescribeCopyJob",
      "backup:DescribeRestoreJob",
      "backup:GetRecoveryPointRestoreMetadata",
      "backup:ListBackupJobs",
      "backup:ListCopyJobs",
      "backup:ListRecoveryPointsByBackupVault",
      "backup:ListRestoreJobs",
      "backup:StartBackupJob",
      "backup:StartCopyJob",
      "backup:StartRestoreJob",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ReadSourceCognitoDirectory"
    effect = "Allow"
    actions = [
      "cognito-idp:AdminGetUser",
      "cognito-idp:AdminListGroupsForUser",
      "cognito-idp:ListGroups",
      "cognito-idp:ListUsers",
    ]
    resources = ["arn:${data.aws_partition.current.partition}:cognito-idp:${var.source_region}:${var.account_id}:userpool/${var.source_cognito_user_pool_id}"]
  }

  statement {
    sid    = "WriteOnlyRecoveryCognitoDirectory"
    effect = "Allow"
    actions = [
      "cognito-idp:AdminAddUserToGroup",
      "cognito-idp:AdminCreateUser",
      "cognito-idp:AdminDisableUser",
      "cognito-idp:AdminEnableUser",
      "cognito-idp:AdminGetUser",
      "cognito-idp:AdminListGroupsForUser",
      "cognito-idp:AdminResetUserPassword",
      "cognito-idp:AdminUpdateUserAttributes",
      "cognito-idp:CreateGroup",
      "cognito-idp:ListGroups",
      "cognito-idp:ListUsers",
    ]
    resources = [var.destination_cognito_user_pool_arn]
  }

  statement {
    sid    = "ReadSourceSesTemplates"
    effect = "Allow"
    actions = [
      "ses:GetTemplate",
      "ses:ListTemplates",
    ]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [var.source_region]
    }
  }

  statement {
    sid    = "ManageRecoverySesTemplates"
    effect = "Allow"
    actions = [
      "ses:CreateTemplate",
      "ses:GetTemplate",
      "ses:ListTemplates",
      "ses:UpdateTemplate",
    ]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [data.aws_region.destination.region]
    }
  }

  statement {
    sid       = "PassOnlyEatinityBackupRole"
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = [aws_iam_role.backup.arn]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["backup.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "operator" {
  provider    = aws.source
  name        = "${var.resource_prefix}-backup-operator"
  description = "Operate Eatinity AWS Backup, copy, and restore jobs."
  policy      = data.aws_iam_policy_document.operator.json
  tags        = var.tags
}

resource "aws_iam_user_policy_attachment" "operator" {
  provider   = aws.source
  user       = var.operator_user_name
  policy_arn = aws_iam_policy.operator.arn
}

resource "aws_backup_vault" "source" {
  provider      = aws.source
  name          = "${var.resource_prefix}-source-vault"
  force_destroy = false
  tags          = var.tags
}

resource "aws_backup_vault" "destination" {
  provider      = aws.destination
  name          = "${var.resource_prefix}-recovery-vault"
  force_destroy = false
  tags          = var.tags
}

resource "aws_backup_plan" "cross_region" {
  provider = aws.source
  name     = "${var.resource_prefix}-cross-region-plan"
  tags     = var.tags

  rule {
    rule_name         = "${var.resource_prefix}-daily"
    target_vault_name = aws_backup_vault.source.name
    schedule          = var.schedule_expression
    start_window      = 60
    completion_window = 720

    lifecycle {
      delete_after = var.source_retention_days
    }

    copy_action {
      destination_vault_arn = aws_backup_vault.destination.arn
      lifecycle {
        delete_after = var.recovery_retention_days
      }
    }

    recovery_point_tags = merge(var.tags, { BackupTier = "CrossRegion" })
  }
}

resource "aws_backup_selection" "eatinity" {
  provider     = aws.source
  name         = "${var.resource_prefix}-source-resources"
  plan_id      = aws_backup_plan.cross_region.id
  iam_role_arn = aws_iam_role.backup.arn
  resources    = local.source_resources
}
