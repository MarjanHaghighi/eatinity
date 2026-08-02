output "aws_account_id" { value = data.aws_caller_identity.current.account_id }
output "aws_region" { value = var.aws_region }
output "resource_prefix" { value = local.resource_prefix }
output "api_endpoint" { value = module.application.api_endpoint }
output "products_api_url" { value = module.application.products_api_url }
output "categories_api_url" { value = module.application.categories_api_url }
output "stripe_webhook_url" { value = module.application.stripe_webhook_url }
output "cognito_user_pool_id" { value = module.identity.user_pool_id }
output "cognito_client_id" { value = module.identity.user_pool_client_id }
output "website_bucket_name" { value = module.storage.website.name }
output "images_bucket_name" { value = module.storage.images.name }
output "cloudfront_domain_name" { value = module.delivery.cloudfront_domain_name }
output "cloudfront_distribution_id" { value = module.delivery.cloudfront_distribution_id }
output "stripe_secret_name" { value = module.secrets.stripe_secret_name }
output "stripe_secret_arn" {
  value     = module.secrets.stripe_secret_arn
  sensitive = true
}
output "frontend_base_url" { value = local.frontend_base_url }
output "dynamodb_table_names" { value = module.database.names }
output "ses_recovery" {
  value = var.enable_ses ? {
    region                 = var.aws_region
    domain                 = var.domain_name
    configuration_set_name = module.operations.ses_configuration_set_name
    bounce_topic_arn       = module.operations.ses_bounce_topic_arn
    complaint_topic_arn    = module.operations.ses_complaint_topic_arn
    mail_from_domain       = module.operations.ses_mail_from_domain
  } : null
}
output "backup_recovery" {
  value = var.enable_enterprise_backup ? {
    source_vault_name      = module.recovery_backup[0].source_vault_name
    destination_vault_name = module.recovery_backup[0].destination_vault_name
    destination_vault_arn  = module.recovery_backup[0].destination_vault_arn
    backup_plan_id         = module.recovery_backup[0].backup_plan_id
    backup_role_arn        = module.recovery_backup[0].backup_role_arn
    operator_policy_arn    = module.recovery_backup[0].operator_policy_arn
  } : null
}
output "recovery_configuration" {
  value = {
    account_id = data.aws_caller_identity.current.account_id
    source = {
      region               = var.source_aws_region
      table_names          = var.source_table_names
      bucket_names         = var.source_bucket_names
      cognito_user_pool_id = var.source_cognito_user_pool_id
    }
    destination = {
      region      = var.aws_region
      table_names = module.database.names
      bucket_names = {
        images  = module.storage.images.name
        website = module.storage.website.name
      }
      cognito_user_pool_id = module.identity.user_pool_id
    }
  }
}
