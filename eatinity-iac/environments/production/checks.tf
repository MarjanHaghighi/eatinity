check "existing_cognito_configuration" {
  assert {
    condition = (
      var.create_cognito_resources ||
      (var.existing_cognito_user_pool_id != null && var.existing_cognito_client_id != null)
    )
    error_message = "When Cognito creation is disabled, both existing Cognito IDs are required."
  }
}

check "custom_domain_certificate" {
  assert {
    condition     = !var.use_custom_domain || var.acm_certificate_arn != null
    error_message = "A CloudFront ACM certificate ARN is required when the custom domain is enabled."
  }
}

check "public_dns_configuration" {
  assert {
    condition     = !var.manage_public_dns || var.use_custom_domain
    error_message = "Public website DNS requires the custom domain and its CloudFront certificate."
  }
}

check "ses_dns_configuration" {
  assert {
    condition     = !var.manage_ses_dns || var.enable_ses
    error_message = "SES DNS management requires enable_ses = true."
  }
}

check "recovery_region_guard" {
  assert {
    condition     = var.aws_region != "us-east-1" || var.allow_main_region_deployment
    error_message = "The existing main region is blocked. Set allow_main_region_deployment only for the later reviewed main-region workflow."
  }
}

check "disposable_cleanup_settings" {
  assert {
    condition = (
      !var.disposable_environment ||
      (var.force_destroy_buckets && !var.enable_deletion_protection)
    )
    error_message = "A disposable stack requires force-destroy buckets and deletion protection disabled."
  }
}
