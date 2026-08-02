data "aws_caller_identity" "current" {
  lifecycle {
    precondition {
      condition     = var.aws_region != "us-east-1" || var.allow_main_region_deployment
      error_message = "The existing main region is blocked until allow_main_region_deployment is explicitly enabled."
    }

    precondition {
      condition = (
        !var.disposable_environment ||
        (var.force_destroy_buckets && !var.enable_deletion_protection)
      )
      error_message = "A disposable stack requires force-destroy buckets and deletion protection disabled."
    }

    precondition {
      condition = (
        var.create_cognito_resources ||
        (var.existing_cognito_user_pool_id != null && var.existing_cognito_client_id != null)
      )
      error_message = "When Cognito creation is disabled, both existing Cognito IDs are required."
    }

    precondition {
      condition     = !var.use_custom_domain || var.acm_certificate_arn != null
      error_message = "A CloudFront ACM certificate ARN is required when the custom domain is enabled."
    }

    precondition {
      condition     = !var.manage_public_dns || var.use_custom_domain
      error_message = "Public website DNS requires the custom domain and its CloudFront certificate."
    }
  }
}

module "identity" {
  source                       = "../../modules/identity"
  resource_prefix              = local.resource_prefix
  create_user_pool             = var.create_cognito_resources
  enable_deletion_protection   = var.enable_deletion_protection
  existing_user_pool_id        = var.existing_cognito_user_pool_id
  existing_user_pool_client_id = var.existing_cognito_client_id
  callback_urls                = distinct(concat(var.cognito_callback_urls, [local.frontend_base_url]))
  logout_urls                  = distinct(concat(var.cognito_logout_urls, [local.frontend_base_url]))
  tags                         = local.common_tags
}

module "database" {
  source                        = "../../modules/database"
  table_names                   = local.table_names
  enable_point_in_time_recovery = var.enable_point_in_time_recovery
  enable_deletion_protection    = var.enable_deletion_protection
  tags                          = local.common_tags
}

module "storage" {
  source              = "../../modules/storage"
  website_bucket_name = local.website_bucket_name
  images_bucket_name  = local.images_bucket_name
  enable_versioning   = var.enable_s3_versioning
  force_destroy       = var.force_destroy_buckets
  tags                = local.common_tags
}

module "secrets" {
  source                  = "../../modules/secrets"
  resource_prefix         = local.resource_prefix
  recovery_window_in_days = var.secret_recovery_window_days
  tags                    = local.common_tags
}

data "aws_route53_zone" "ses" {
  count        = var.enable_ses && var.manage_ses_dns ? 1 : 0
  name         = var.domain_name
  private_zone = false
}

module "operations" {
  source                       = "../../modules/operations"
  resource_prefix              = local.resource_prefix
  enable_ses                   = var.enable_ses
  ses_domain                   = var.domain_name
  manage_ses_dns               = var.manage_ses_dns
  ses_route53_zone_id          = var.enable_ses && var.manage_ses_dns ? data.aws_route53_zone.ses[0].zone_id : null
  ses_notification_emails      = var.ses_notification_emails
  ses_sandbox_recipient_emails = var.ses_sandbox_recipient_emails
  sns_email_subscriptions      = var.sns_email_subscriptions
  tags                         = local.common_tags
}

module "delivery" {
  source              = "../../modules/delivery"
  resource_prefix     = local.resource_prefix
  website_bucket      = module.storage.website
  domain_name         = var.domain_name
  use_custom_domain   = var.use_custom_domain
  acm_certificate_arn = var.acm_certificate_arn
  manage_public_dns   = var.manage_public_dns
  aws_region          = var.aws_region
  tags                = local.common_tags
}

locals {
  frontend_base_url = var.use_custom_domain ? "https://${var.domain_name}" : "https://${module.delivery.cloudfront_domain_name}"
}

moved {
  from = module.storage.aws_s3_bucket_cors_configuration.images
  to   = aws_s3_bucket_cors_configuration.images
}

resource "aws_s3_bucket_cors_configuration" "images" {
  bucket = module.storage.images.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD", "POST"]
    allowed_origins = distinct(concat(var.allowed_origins, [local.frontend_base_url]))
    expose_headers  = ["ETag"]
    max_age_seconds = 300
  }
}

module "application" {
  source                = "../../modules/application"
  resource_prefix       = local.resource_prefix
  aws_region            = var.aws_region
  api_name              = "${local.resource_prefix}-api"
  allowed_origins       = distinct(concat(var.allowed_origins, [local.frontend_base_url]))
  cognito_user_pool_id  = module.identity.user_pool_id
  cognito_user_pool_arn = module.identity.user_pool_arn
  cognito_client_id     = module.identity.user_pool_client_id
  table_names           = module.database.names
  table_arns            = module.database.arns
  images_bucket         = module.storage.images
  sns_topic_arn         = module.operations.sns_topic_arn
  ses_from_email        = var.ses_from_email
  stripe_secret_arn     = module.secrets.stripe_secret_arn
  frontend_success_url  = "${local.frontend_base_url}/success?session_id={CHECKOUT_SESSION_ID}"
  frontend_cancel_url   = "${local.frontend_base_url}/cancel"
  log_retention_days    = var.cloudwatch_log_retention_days
  tags                  = local.common_tags
}

module "recovery_backup" {
  count  = var.enable_enterprise_backup ? 1 : 0
  source = "../../modules/recovery_backup"

  providers = {
    aws.source      = aws.source
    aws.destination = aws
  }

  resource_prefix                   = local.resource_prefix
  account_id                        = data.aws_caller_identity.current.account_id
  source_region                     = var.source_aws_region
  source_table_names                = var.source_table_names
  source_bucket_names               = var.source_bucket_names
  source_cognito_user_pool_id       = var.source_cognito_user_pool_id
  destination_cognito_user_pool_arn = module.identity.user_pool_arn
  schedule_expression               = var.backup_schedule_expression
  source_retention_days             = var.source_backup_retention_days
  recovery_retention_days           = var.recovery_backup_retention_days
  operator_user_name                = var.backup_operator_user_name
  tags                              = local.common_tags
}
