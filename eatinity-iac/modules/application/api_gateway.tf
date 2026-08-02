resource "aws_apigatewayv2_api" "api" {
  name          = var.api_name
  protocol_type = "HTTP"
  tags          = var.tags

  cors_configuration {
    allow_origins = var.allowed_origins
    allow_methods = ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"]
    allow_headers = ["Content-Type", "Authorization", "Stripe-Signature"]
    max_age       = 300
  }
}

resource "aws_apigatewayv2_authorizer" "cognito" {
  api_id           = aws_apigatewayv2_api.api.id
  authorizer_type  = "JWT"
  name             = "${var.resource_prefix}-cognito-authorizer"
  identity_sources = ["$request.header.Authorization"]

  jwt_configuration {
    audience = [var.cognito_client_id]
    issuer   = "https://cognito-idp.${var.aws_region}.amazonaws.com/${var.cognito_user_pool_id}"
  }
}

resource "aws_apigatewayv2_integration" "get_products" {
  api_id                 = aws_apigatewayv2_api.api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.get_products.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "create_checkout_session" {
  api_id                 = aws_apigatewayv2_api.api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.create_checkout_session.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "stripe_webhook" {
  api_id                 = aws_apigatewayv2_api.api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.stripe_webhook.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "user_profile" {
  api_id                 = aws_apigatewayv2_api.api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.user_profile.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "admin_menu" {
  api_id                 = aws_apigatewayv2_api.api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.admin_menu.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "admin_orders" {
  api_id                 = aws_apigatewayv2_api.api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.admin_orders.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "admin_users" {
  api_id                 = aws_apigatewayv2_api.api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.admin_users.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "sales_reports" {
  api_id                 = aws_apigatewayv2_api.api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.sales_reports.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "admin_audit" {
  api_id                 = aws_apigatewayv2_api.api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.admin_audit.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "get_products_route" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "GET /products"
  target    = "integrations/${aws_apigatewayv2_integration.get_products.id}"
}

# The storefront loads this public endpoint alongside GET /products.
resource "aws_apigatewayv2_route" "get_categories_route" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "GET /categories"
  target    = "integrations/${aws_apigatewayv2_integration.admin_menu.id}"
}

resource "aws_apigatewayv2_route" "create_checkout_session_route" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "POST /create-checkout-session"
  target    = "integrations/${aws_apigatewayv2_integration.create_checkout_session.id}"
}

resource "aws_apigatewayv2_route" "stripe_webhook_route" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "POST /stripe-webhook"
  target    = "integrations/${aws_apigatewayv2_integration.stripe_webhook.id}"
}

resource "aws_apigatewayv2_route" "get_user_profile_route" {
  api_id             = aws_apigatewayv2_api.api.id
  route_key          = "GET /user-profile"
  target             = "integrations/${aws_apigatewayv2_integration.user_profile.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

resource "aws_apigatewayv2_route" "put_user_profile_route" {
  api_id             = aws_apigatewayv2_api.api.id
  route_key          = "PUT /user-profile"
  target             = "integrations/${aws_apigatewayv2_integration.user_profile.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

resource "aws_apigatewayv2_route" "options_user_profile_route" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "OPTIONS /user-profile"
  target    = "integrations/${aws_apigatewayv2_integration.user_profile.id}"
}

resource "aws_apigatewayv2_route" "get_user_orders_route" {
  api_id             = aws_apigatewayv2_api.api.id
  route_key          = "GET /user-orders"
  target             = "integrations/${aws_apigatewayv2_integration.user_profile.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

resource "aws_apigatewayv2_route" "options_user_orders_route" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "OPTIONS /user-orders"
  target    = "integrations/${aws_apigatewayv2_integration.user_profile.id}"
}

resource "aws_apigatewayv2_route" "create_authenticated_checkout_session_route" {
  api_id             = aws_apigatewayv2_api.api.id
  route_key          = "POST /authenticated/create-checkout-session"
  target             = "integrations/${aws_apigatewayv2_integration.create_checkout_session.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

locals {
  admin_menu_routes = toset([
    "GET /admin/products",
    "POST /admin/products",
    "PUT /admin/products/{productId}",
    "PATCH /admin/products/{productId}/availability",
    "PATCH /admin/products/{productId}/restore",
    "DELETE /admin/products/{productId}",
    "GET /admin/categories",
    "POST /admin/categories",
    "PUT /admin/categories/{categoryId}",
    "POST /admin/uploads/product-image",
  ])
}

resource "aws_apigatewayv2_route" "admin_menu" {
  for_each = local.admin_menu_routes

  api_id             = aws_apigatewayv2_api.api.id
  route_key          = each.value
  target             = "integrations/${aws_apigatewayv2_integration.admin_menu.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

locals {
  admin_order_routes = toset([
    "GET /admin/orders",
    "GET /admin/orders/{orderId}",
    "PATCH /admin/orders/{orderId}/status",
  ])
}

resource "aws_apigatewayv2_route" "admin_orders" {
  for_each = local.admin_order_routes

  api_id             = aws_apigatewayv2_api.api.id
  route_key          = each.value
  target             = "integrations/${aws_apigatewayv2_integration.admin_orders.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

locals {
  admin_user_routes = toset([
    "GET /admin/users",
    "POST /admin/staff",
    "PATCH /admin/staff/{username}/role",
    "POST /admin/staff/{username}/disable",
    "POST /admin/staff/{username}/enable",
    "POST /admin/staff/{username}/reset-password",
  ])
}

resource "aws_apigatewayv2_route" "admin_users" {
  for_each = local.admin_user_routes

  api_id             = aws_apigatewayv2_api.api.id
  route_key          = each.value
  target             = "integrations/${aws_apigatewayv2_integration.admin_users.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

resource "aws_apigatewayv2_route" "sales_reports" {
  api_id             = aws_apigatewayv2_api.api.id
  route_key          = "GET /admin/reports/sales"
  target             = "integrations/${aws_apigatewayv2_integration.sales_reports.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

resource "aws_apigatewayv2_route" "admin_audit" {
  api_id             = aws_apigatewayv2_api.api.id
  route_key          = "GET /admin/audit-log"
  target             = "integrations/${aws_apigatewayv2_integration.admin_audit.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

resource "aws_apigatewayv2_stage" "default_stage" {
  api_id      = aws_apigatewayv2_api.api.id
  name        = "$default"
  auto_deploy = true
  tags        = var.tags

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      requestId        = "$context.requestId"
      requestTime      = "$context.requestTime"
      httpMethod       = "$context.httpMethod"
      routeKey         = "$context.routeKey"
      status           = "$context.status"
      responseLength   = "$context.responseLength"
      integrationError = "$context.integrationErrorMessage"
    })
  }
}

resource "aws_lambda_permission" "allow_api_gateway_get_products" {
  statement_id  = "AllowAPIGatewayInvokeGetProducts"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_products.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "allow_api_gateway_checkout" {
  statement_id  = "AllowAPIGatewayInvokeCheckout"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.create_checkout_session.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "allow_api_gateway_webhook" {
  statement_id  = "AllowAPIGatewayInvokeWebhook"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.stripe_webhook.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "allow_api_gateway_user_profile" {
  statement_id  = "AllowAPIGatewayInvokeUserProfile"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.user_profile.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "allow_api_gateway_admin_menu" {
  statement_id  = "AllowAPIGatewayInvokeAdminMenu"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.admin_menu.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "allow_api_gateway_admin_orders" {
  statement_id  = "AllowAPIGatewayInvokeAdminOrders"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.admin_orders.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "allow_api_gateway_admin_users" {
  statement_id  = "AllowAPIGatewayInvokeAdminUsers"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.admin_users.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "allow_api_gateway_sales_reports" {
  statement_id  = "AllowAPIGatewayInvokeSalesReports"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.sales_reports.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "allow_api_gateway_admin_audit" {
  statement_id  = "AllowAPIGatewayInvokeAdminAudit"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.admin_audit.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}
