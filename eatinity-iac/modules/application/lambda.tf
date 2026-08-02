resource "aws_lambda_function" "get_products" {
  function_name = "${var.resource_prefix}-get-products"
  role          = aws_iam_role.lambda.arn
  handler       = "get_products.lambda_handler"
  runtime       = "python3.12"
  tags          = var.tags

  filename         = "${path.module}/../../../eatinity-prod/lambda/get_products.zip"
  source_code_hash = filebase64sha256("${path.module}/../../../eatinity-prod/lambda/get_products.zip")

  environment {
    variables = {
      PRODUCTS_TABLE_NAME = var.table_names.products
      IMAGE_BASE_URL      = "https://${var.images_bucket.domain}/"
    }
  }

}

resource "aws_lambda_function" "admin_menu" {
  function_name = "${var.resource_prefix}-admin-menu"
  role          = aws_iam_role.lambda.arn
  handler       = "admin_menu.lambda_handler"
  runtime       = "python3.12"
  tags          = var.tags

  filename         = "${path.module}/../../../eatinity-prod/lambda/admin_menu.zip"
  source_code_hash = filebase64sha256("${path.module}/../../../eatinity-prod/lambda/admin_menu.zip")

  timeout     = 30
  memory_size = 256

  environment {
    variables = {
      PRODUCTS_TABLE_NAME   = var.table_names.products
      CATEGORIES_TABLE_NAME = var.table_names.categories
      AUDIT_TABLE_NAME      = var.table_names.audit
      IMAGE_BUCKET_NAME     = var.images_bucket.id
    }
  }
}

resource "aws_lambda_function" "admin_orders" {
  function_name = "${var.resource_prefix}-admin-orders"
  role          = aws_iam_role.lambda.arn
  handler       = "admin_orders.lambda_handler"
  runtime       = "python3.12"
  tags          = var.tags

  filename         = "${path.module}/../../../eatinity-prod/lambda/admin_orders.zip"
  source_code_hash = filebase64sha256("${path.module}/../../../eatinity-prod/lambda/admin_orders.zip")

  timeout     = 30
  memory_size = 256

  environment {
    variables = {
      ORDERS_TABLE_NAME = var.table_names.orders
      AUDIT_TABLE_NAME  = var.table_names.audit
      SES_FROM_EMAIL    = var.ses_from_email
    }
  }
}

resource "aws_lambda_function" "admin_users" {
  function_name = "${var.resource_prefix}-admin-users"
  role          = aws_iam_role.lambda.arn
  handler       = "admin_users.lambda_handler"
  runtime       = "python3.12"
  tags          = var.tags

  filename         = "${path.module}/../../../eatinity-prod/lambda/admin_users.zip"
  source_code_hash = filebase64sha256("${path.module}/../../../eatinity-prod/lambda/admin_users.zip")

  timeout     = 30
  memory_size = 256

  environment {
    variables = {
      USER_POOL_ID     = var.cognito_user_pool_id
      USERS_TABLE_NAME = var.table_names.users
      AUDIT_TABLE_NAME = var.table_names.audit
    }
  }
}

resource "aws_lambda_function" "sales_reports" {
  function_name = "${var.resource_prefix}-sales-reports"
  role          = aws_iam_role.lambda.arn
  handler       = "sales_reports.lambda_handler"
  runtime       = "python3.12"
  tags          = var.tags

  filename         = "${path.module}/../../../eatinity-prod/lambda/sales_reports.zip"
  source_code_hash = filebase64sha256("${path.module}/../../../eatinity-prod/lambda/sales_reports.zip")

  timeout     = 30
  memory_size = 256

  environment {
    variables = {
      ORDERS_TABLE_NAME = var.table_names.orders
      BUSINESS_TIMEZONE = "America/Toronto"
    }
  }
}

resource "aws_lambda_function" "admin_audit" {
  function_name = "${var.resource_prefix}-admin-audit"
  role          = aws_iam_role.lambda.arn
  handler       = "admin_audit.lambda_handler"
  runtime       = "python3.12"
  tags          = var.tags

  filename         = "${path.module}/../../../eatinity-prod/lambda/admin_audit.zip"
  source_code_hash = filebase64sha256("${path.module}/../../../eatinity-prod/lambda/admin_audit.zip")

  timeout     = 30
  memory_size = 128

  environment {
    variables = {
      AUDIT_TABLE_NAME = var.table_names.audit
    }
  }
}

resource "aws_lambda_function" "create_checkout_session" {
  function_name = "${var.resource_prefix}-create-checkout-session"
  role          = aws_iam_role.lambda.arn
  handler       = "create_checkout_session.lambda_handler"
  runtime       = "python3.12"
  tags          = var.tags

  filename         = "${path.module}/../../../eatinity-prod/lambda/stripe_checkout.zip"
  source_code_hash = filebase64sha256("${path.module}/../../../eatinity-prod/lambda/stripe_checkout.zip")

  timeout     = 30
  memory_size = 256

  environment {
    variables = {
      ORDERS_TABLE_NAME   = var.table_names.orders
      PRODUCTS_TABLE_NAME = var.table_names.products
      STRIPE_SECRET_ARN   = var.stripe_secret_arn
      SUCCESS_URL         = var.frontend_success_url
      CANCEL_URL          = var.frontend_cancel_url
    }
  }

}

resource "aws_lambda_function" "stripe_webhook" {
  function_name = "${var.resource_prefix}-stripe-webhook"
  role          = aws_iam_role.lambda.arn
  handler       = "process_stripe_webhook.lambda_handler"
  runtime       = "python3.12"
  tags          = var.tags

  filename         = "${path.module}/../../../eatinity-prod/lambda/stripe_webhook.zip"
  source_code_hash = filebase64sha256("${path.module}/../../../eatinity-prod/lambda/stripe_webhook.zip")

  timeout     = 30
  memory_size = 256

  environment {
    variables = {
      ORDERS_TABLE_NAME = var.table_names.orders
      STRIPE_SECRET_ARN = var.stripe_secret_arn
      SES_FROM_EMAIL    = var.ses_from_email
      SNS_TOPIC_ARN     = var.sns_topic_arn
    }
  }

}

resource "aws_lambda_function" "user_profile" {
  function_name = "${var.resource_prefix}-user-profile"
  role          = aws_iam_role.lambda.arn
  handler       = "user_profile.lambda_handler"
  runtime       = "python3.12"
  tags          = var.tags

  filename         = "${path.module}/../../../eatinity-prod/lambda/user_profile.zip"
  source_code_hash = filebase64sha256("${path.module}/../../../eatinity-prod/lambda/user_profile.zip")

  timeout     = 30
  memory_size = 128

  environment {
    variables = {
      USERS_TABLE_NAME  = var.table_names.users
      ORDERS_TABLE_NAME = var.table_names.orders
    }
  }

}

# Optional future Lambda if you separate /user-orders from user_profile.py.
# resource "aws_lambda_function" "user_orders" { ... }
