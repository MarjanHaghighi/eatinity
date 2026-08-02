output "stripe_secret_arn" { value = aws_secretsmanager_secret.stripe.arn }
output "stripe_secret_name" { value = aws_secretsmanager_secret.stripe.name }

