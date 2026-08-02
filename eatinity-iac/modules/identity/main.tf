resource "aws_cognito_user_pool" "this" {
  count = var.create_user_pool ? 1 : 0

  name                     = "${var.resource_prefix}-users"
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length                   = 10
    require_lowercase                = true
    require_numbers                  = true
    require_symbols                  = true
    require_uppercase                = true
    temporary_password_validity_days = 7
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  deletion_protection = var.enable_deletion_protection ? "ACTIVE" : "INACTIVE"
  tags                = var.tags
}

locals {
  user_pool_id  = var.create_user_pool ? aws_cognito_user_pool.this[0].id : var.existing_user_pool_id
  user_pool_arn = var.create_user_pool ? aws_cognito_user_pool.this[0].arn : data.aws_cognito_user_pool.existing[0].arn
}

data "aws_cognito_user_pool" "existing" {
  count = var.create_user_pool ? 0 : 1

  user_pool_id = var.existing_user_pool_id
}

resource "aws_cognito_user_pool_client" "this" {
  count = var.create_user_pool ? 1 : 0

  name         = "${var.resource_prefix}-web"
  user_pool_id = local.user_pool_id

  generate_secret                      = false
  prevent_user_existence_errors        = "ENABLED"
  supported_identity_providers         = ["COGNITO"]
  explicit_auth_flows                  = ["ALLOW_USER_PASSWORD_AUTH", "ALLOW_USER_SRP_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"]
  allowed_oauth_flows_user_pool_client = length(var.callback_urls) > 0
  allowed_oauth_flows                  = length(var.callback_urls) > 0 ? ["code"] : null
  allowed_oauth_scopes                 = length(var.callback_urls) > 0 ? ["email", "openid", "profile"] : null
  callback_urls                        = length(var.callback_urls) > 0 ? var.callback_urls : null
  logout_urls                          = length(var.logout_urls) > 0 ? var.logout_urls : null
}

locals {
  user_pool_client_id = var.create_user_pool ? aws_cognito_user_pool_client.this[0].id : var.existing_user_pool_client_id

  admin_groups = {
    "super-admin" = { description = "Full Eatinity administration, including staff role management.", precedence = 1 }
    admin         = { description = "Manage Eatinity orders, menu, customers, and reports.", precedence = 10 }
    manager       = { description = "Manage Eatinity orders and menu and view reports.", precedence = 20 }
    kitchen       = { description = "View orders and update kitchen preparation statuses.", precedence = 30 }
  }
}

resource "aws_cognito_user_group" "admin" {
  for_each = local.admin_groups

  user_pool_id = local.user_pool_id
  name         = each.key
  description  = each.value.description
  precedence   = each.value.precedence
}
