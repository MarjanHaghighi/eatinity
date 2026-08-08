provider "aws" {
  region = var.aws_region
}

# Legacy Terraform is retained only as historical deployment documentation; the
# active deployment root is eatinity-iac/environments/production.
# S3 bucket for product images
#trivy:ignore:AWS-0086:exp:2026-12-31 trivy:ignore:AWS-0087:exp:2026-12-31 trivy:ignore:AWS-0091:exp:2026-12-31 trivy:ignore:AWS-0093:exp:2026-12-31 trivy:ignore:AWS-0132:exp:2026-12-31
resource "aws_s3_bucket" "images" {
  bucket = var.images_bucket_name
}

# S3 bucket for React website
#trivy:ignore:AWS-0086:exp:2026-12-31 trivy:ignore:AWS-0087:exp:2026-12-31 trivy:ignore:AWS-0091:exp:2026-12-31 trivy:ignore:AWS-0093:exp:2026-12-31 trivy:ignore:AWS-0132:exp:2026-12-31
resource "aws_s3_bucket" "website" {
  bucket = var.website_bucket_name
}


# IAM policy for CLI user to manage the images S3 bucket
resource "aws_iam_policy" "images_bucket_admin_policy" {
  name = "eatinity-images-bucket-admin-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = aws_s3_bucket.images.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:PutObjectAcl"
        ]
        Resource = "${aws_s3_bucket.images.arn}/*"
      }
    ]
  })
}

# Attach policy to your IAM user
resource "aws_iam_user_policy_attachment" "images_bucket_admin_attach" {
  user       = var.iam_user_name
  policy_arn = aws_iam_policy.images_bucket_admin_policy.arn
}

# DynamoDB table
resource "aws_dynamodb_table" "products" {
  name         = "EatinityProducts"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}



# Lambda IAM role
resource "aws_iam_role" "lambda_role" {
  name = "eatinity-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Lambda permissions
resource "aws_iam_policy" "lambda_policy" {
  name = "eatinity-lambda-policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "dynamodb:Scan",
          "dynamodb:GetItem",
          "dynamodb:Query"
        ],
        Resource = aws_dynamodb_table.products.arn
      },
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

# Zip Lambda code
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/get_products.py"
  output_path = "${path.module}/lambda/get_products.zip"
}

# Lambda function
resource "aws_lambda_function" "get_products" {
  function_name = "eatinity-get-products"
  role          = aws_iam_role.lambda_role.arn
  handler       = "get_products.lambda_handler"
  runtime       = "python3.12"

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      PRODUCTS_TABLE_NAME = aws_dynamodb_table.products.name
      IMAGE_BASE_URL      = "https://${var.images_bucket_name}.s3.${var.aws_region}.amazonaws.com/"
    }
  }

  depends_on = [aws_iam_role_policy_attachment.lambda_attach]
}

# API Gateway HTTP API
resource "aws_apigatewayv2_api" "api" {
  name          = "eatinity-products-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "OPTIONS"]
    allow_headers = ["*"]
  }
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id                 = aws_apigatewayv2_api.api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.get_products.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "get_products_route" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "GET /products"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_stage" "default_stage" {
  api_id      = aws_apigatewayv2_api.api.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "allow_api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_products.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}
