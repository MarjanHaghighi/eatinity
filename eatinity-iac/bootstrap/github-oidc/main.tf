data "aws_caller_identity" "current" {}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

data "aws_iam_policy_document" "github_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_owner}/${var.github_repository}:environment:${var.github_environment}"]
    }
  }
}

resource "aws_iam_role" "github_deploy" {
  name                 = "${var.resource_prefix}-github-${var.github_environment}-deploy"
  assume_role_policy   = data.aws_iam_policy_document.github_trust.json
  max_session_duration = 3600
  tags = {
    Project   = "Eatinity"
    ManagedBy = "Terraform"
    Purpose   = "GitHubOIDCDeployment"
  }
}

data "aws_iam_policy_document" "deploy" {
  # Read actions are required by Terraform refresh/plan and generally do not
  # support resource-level restrictions.
  statement {
    sid       = "TerraformRead"
    effect    = "Allow"
    resources = ["*"]
    actions = [
      "acm:DescribeCertificate", "acm:ListCertificates",
      "apigateway:GET", "backup:List*", "backup:Describe*", "backup:Get*",
      "cloudfront:Get*", "cloudfront:List*", "cloudwatch:Describe*",
      "cognito-idp:Describe*", "cognito-idp:List*", "dynamodb:Describe*",
      "dynamodb:List*", "ec2:Describe*", "iam:Get*", "iam:List*",
      "lambda:Get*", "lambda:List*", "logs:Describe*", "route53:Get*",
      "route53:List*", "s3:Get*", "s3:List*", "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecrets", "ses:Get*", "ses:List*", "sns:Get*",
      "sns:List*", "sts:GetCallerIdentity"
    ]
  }

  # Deployment is limited to the service action set used by this repository.
  # Resource names are additionally constrained by the Eatinity Terraform code.
  statement {
    sid       = "EatinityDeployment"
    effect    = "Allow"
    resources = ["*"]
    actions = [
      "apigateway:DELETE", "apigateway:PATCH", "apigateway:POST", "apigateway:PUT",
      "backup:CreateBackupPlan", "backup:CreateBackupSelection", "backup:CreateBackupVault",
      "backup:DeleteBackupPlan", "backup:DeleteBackupSelection", "backup:DeleteBackupVault",
      "backup:TagResource", "backup:UntagResource", "backup:UpdateBackupPlan",
      "cloudfront:CreateDistribution", "cloudfront:CreateInvalidation", "cloudfront:DeleteDistribution",
      "cloudfront:TagResource", "cloudfront:UpdateDistribution",
      "cognito-idp:CreateGroup", "cognito-idp:CreateUserPool", "cognito-idp:CreateUserPoolClient",
      "cognito-idp:DeleteGroup", "cognito-idp:DeleteUserPool", "cognito-idp:DeleteUserPoolClient",
      "cognito-idp:TagResource", "cognito-idp:UpdateGroup", "cognito-idp:UpdateUserPool",
      "cognito-idp:UpdateUserPoolClient", "dynamodb:CreateTable", "dynamodb:DeleteTable",
      "dynamodb:TagResource", "dynamodb:UntagResource", "dynamodb:UpdateContinuousBackups",
      "dynamodb:UpdateTable", "lambda:AddPermission", "lambda:CreateFunction", "lambda:DeleteFunction",
      "lambda:RemovePermission", "lambda:TagResource", "lambda:UpdateFunctionCode",
      "lambda:UpdateFunctionConfiguration", "logs:CreateLogGroup", "logs:DeleteLogGroup",
      "logs:PutRetentionPolicy", "route53:ChangeResourceRecordSets", "s3:CreateBucket",
      "s3:DeleteBucket", "s3:DeleteBucketPolicy", "s3:DeleteBucketWebsite", "s3:PutBucketCORS",
      "s3:PutBucketPolicy", "s3:PutBucketTagging", "s3:PutBucketVersioning", "s3:PutBucketWebsite",
      "s3:PutEncryptionConfiguration", "s3:PutObject", "s3:DeleteObject",
      "secretsmanager:CreateSecret", "secretsmanager:DeleteSecret", "secretsmanager:PutResourcePolicy",
      "secretsmanager:TagResource", "secretsmanager:UntagResource", "secretsmanager:UpdateSecret",
      "ses:SetIdentityNotificationTopic", "sns:CreateTopic", "sns:DeleteTopic", "sns:Subscribe",
      "sns:SetTopicAttributes", "sns:TagResource", "sns:Unsubscribe"
    ]
  }

  statement {
    sid    = "ManageEatinityIAM"
    effect = "Allow"
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.resource_prefix}-*",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${var.resource_prefix}-*"
    ]
    actions = [
      "iam:AttachRolePolicy", "iam:CreatePolicy", "iam:CreatePolicyVersion", "iam:CreateRole",
      "iam:DeletePolicy", "iam:DeletePolicyVersion", "iam:DeleteRole", "iam:DeleteRolePolicy",
      "iam:DetachRolePolicy", "iam:PassRole", "iam:PutRolePolicy", "iam:TagPolicy", "iam:TagRole",
      "iam:UpdateAssumeRolePolicy"
    ]
  }

  statement {
    sid       = "TerraformState"
    effect    = "Allow"
    resources = [var.terraform_state_bucket_arn, "${var.terraform_state_bucket_arn}/*"]
    actions   = ["s3:GetBucketVersioning", "s3:GetObject", "s3:ListBucket", "s3:PutObject"]
  }
}

resource "aws_iam_policy" "github_deploy" {
  name        = "${var.resource_prefix}-github-${var.github_environment}-deploy"
  description = "Service-limited deployment policy for the Eatinity GitHub Actions workflow."
  policy      = data.aws_iam_policy_document.deploy.json
}

resource "aws_iam_role_policy_attachment" "github_deploy" {
  role       = aws_iam_role.github_deploy.name
  policy_arn = aws_iam_policy.github_deploy.arn
}

