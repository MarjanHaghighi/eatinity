locals {
  lambda_function_names = toset([
    aws_lambda_function.get_products.function_name,
    aws_lambda_function.admin_menu.function_name,
    aws_lambda_function.admin_orders.function_name,
    aws_lambda_function.admin_users.function_name,
    aws_lambda_function.sales_reports.function_name,
    aws_lambda_function.admin_audit.function_name,
    aws_lambda_function.create_checkout_session.function_name,
    aws_lambda_function.stripe_webhook.function_name,
    aws_lambda_function.user_profile.function_name,
  ])
}

resource "aws_cloudwatch_log_group" "lambda" {
  for_each = local.lambda_function_names

  name              = "/aws/lambda/${each.value}"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${var.api_name}"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}
