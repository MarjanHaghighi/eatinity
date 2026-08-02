resource "aws_secretsmanager_secret" "stripe" {
  name                    = "${var.resource_prefix}/stripe"
  description             = "Stripe test-mode credentials used by Eatinity payment Lambdas."
  recovery_window_in_days = var.recovery_window_in_days
  tags                    = var.tags
}

