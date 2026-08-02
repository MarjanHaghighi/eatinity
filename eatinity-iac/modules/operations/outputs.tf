output "sns_topic_arn" { value = aws_sns_topic.orders.arn }
output "ses_verification_token" { value = var.enable_ses ? aws_ses_domain_identity.this[0].verification_token : null }
output "ses_dkim_tokens" { value = var.enable_ses ? aws_ses_domain_dkim.this[0].dkim_tokens : [] }
output "ses_mail_from_domain" { value = "${var.resource_prefix}-mail.${var.ses_domain}" }
output "ses_configuration_set_name" { value = var.enable_ses ? aws_ses_configuration_set.recovery[0].name : null }
output "ses_bounce_topic_arn" { value = var.enable_ses ? aws_sns_topic.ses_bounce[0].arn : null }
output "ses_complaint_topic_arn" { value = var.enable_ses ? aws_sns_topic.ses_complaint[0].arn : null }
