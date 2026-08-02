output "api_endpoint" { value = aws_apigatewayv2_api.api.api_endpoint }
output "products_api_url" { value = "${aws_apigatewayv2_api.api.api_endpoint}/products" }
output "categories_api_url" { value = "${aws_apigatewayv2_api.api.api_endpoint}/categories" }
output "stripe_webhook_url" { value = "${aws_apigatewayv2_api.api.api_endpoint}/stripe-webhook" }
output "lambda_function_names" { value = local.lambda_function_names }
output "lambda_role_arn" { value = aws_iam_role.lambda.arn }
