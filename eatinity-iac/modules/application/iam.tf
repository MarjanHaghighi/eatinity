resource "aws_iam_role" "lambda" {
  name = "${var.resource_prefix}-lambda-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
  tags = var.tags
}

resource "aws_iam_policy" "lambda" {
  name        = "${var.resource_prefix}-lambda-runtime"
  description = "Least-privilege runtime access for Eatinity ${var.resource_prefix}."
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem", "dynamodb:BatchGetItem", "dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:Query", "dynamodb:Scan"]
        Resource = concat(values(var.table_arns), [for arn in values(var.table_arns) : "${arn}/index/*"])
      },
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = "${var.images_bucket.arn}/foods/*"
      },
      {
        Effect   = "Allow"
        Action   = ["cognito-idp:ListUsers", "cognito-idp:AdminListGroupsForUser", "cognito-idp:ListUsersInGroup", "cognito-idp:AdminGetUser", "cognito-idp:AdminCreateUser", "cognito-idp:AdminAddUserToGroup", "cognito-idp:AdminRemoveUserFromGroup", "cognito-idp:AdminEnableUser", "cognito-idp:AdminDisableUser", "cognito-idp:AdminResetUserPassword"]
        Resource = var.cognito_user_pool_arn
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["ses:SendEmail", "ses:SendRawEmail"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = var.sns_topic_arn
      },
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = var.stripe_secret_arn
      }
    ]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "lambda" {
  role       = aws_iam_role.lambda.name
  policy_arn = aws_iam_policy.lambda.arn
}
