resource "aws_ses_domain_identity" "this" {
  count  = var.enable_ses ? 1 : 0
  domain = var.ses_domain
}

resource "aws_ses_domain_dkim" "this" {
  count  = var.enable_ses ? 1 : 0
  domain = aws_ses_domain_identity.this[0].domain
}

resource "aws_ses_domain_mail_from" "this" {
  count                  = var.enable_ses ? 1 : 0
  domain                 = aws_ses_domain_identity.this[0].domain
  mail_from_domain       = "${var.resource_prefix}-mail.${var.ses_domain}"
  behavior_on_mx_failure = "UseDefaultValue"
}

data "aws_region" "current" {}

resource "aws_ses_configuration_set" "recovery" {
  count = var.enable_ses ? 1 : 0
  name  = "${var.resource_prefix}-transactional"
}

resource "aws_ses_email_identity" "sandbox_recipient" {
  for_each = var.enable_ses ? var.ses_sandbox_recipient_emails : toset([])
  email    = each.value
}

resource "aws_sns_topic" "ses_bounce" {
  count             = var.enable_ses ? 1 : 0
  name              = "${var.resource_prefix}-ses-bounces"
  kms_master_key_id = "alias/aws/sns"
  tags              = var.tags
}

resource "aws_sns_topic" "ses_complaint" {
  count             = var.enable_ses ? 1 : 0
  name              = "${var.resource_prefix}-ses-complaints"
  kms_master_key_id = "alias/aws/sns"
  tags              = var.tags
}

resource "aws_ses_identity_notification_topic" "bounce" {
  count                    = var.enable_ses ? 1 : 0
  identity                 = aws_ses_domain_identity.this[0].domain
  notification_type        = "Bounce"
  topic_arn                = aws_sns_topic.ses_bounce[0].arn
  include_original_headers = false
}

resource "aws_ses_identity_notification_topic" "complaint" {
  count                    = var.enable_ses ? 1 : 0
  identity                 = aws_ses_domain_identity.this[0].domain
  notification_type        = "Complaint"
  topic_arn                = aws_sns_topic.ses_complaint[0].arn
  include_original_headers = false
}

resource "aws_sns_topic_subscription" "ses_bounce_email" {
  for_each  = var.enable_ses ? var.ses_notification_emails : toset([])
  topic_arn = aws_sns_topic.ses_bounce[0].arn
  protocol  = "email"
  endpoint  = each.value
}

resource "aws_sns_topic_subscription" "ses_complaint_email" {
  for_each  = var.enable_ses ? var.ses_notification_emails : toset([])
  topic_arn = aws_sns_topic.ses_complaint[0].arn
  protocol  = "email"
  endpoint  = each.value
}

resource "aws_route53_record" "ses_identity" {
  count   = var.enable_ses && var.manage_ses_dns ? 1 : 0
  zone_id = var.ses_route53_zone_id
  name    = "_amazonses.${var.ses_domain}"
  type    = "TXT"
  ttl     = 600
  records = [aws_ses_domain_identity.this[0].verification_token]
}

resource "aws_route53_record" "ses_dkim" {
  count   = var.enable_ses && var.manage_ses_dns ? 3 : 0
  zone_id = var.ses_route53_zone_id
  name    = "${aws_ses_domain_dkim.this[0].dkim_tokens[count.index]}._domainkey.${var.ses_domain}"
  type    = "CNAME"
  ttl     = 600
  records = ["${aws_ses_domain_dkim.this[0].dkim_tokens[count.index]}.dkim.amazonses.com"]
}

resource "aws_route53_record" "ses_mail_from_mx" {
  count   = var.enable_ses && var.manage_ses_dns ? 1 : 0
  zone_id = var.ses_route53_zone_id
  name    = aws_ses_domain_mail_from.this[0].mail_from_domain
  type    = "MX"
  ttl     = 600
  records = ["10 feedback-smtp.${data.aws_region.current.region}.amazonses.com"]
}

resource "aws_route53_record" "ses_mail_from_spf" {
  count   = var.enable_ses && var.manage_ses_dns ? 1 : 0
  zone_id = var.ses_route53_zone_id
  name    = aws_ses_domain_mail_from.this[0].mail_from_domain
  type    = "TXT"
  ttl     = 600
  records = ["v=spf1 include:amazonses.com -all"]
}

resource "aws_sns_topic" "orders" {
  name              = "${var.resource_prefix}-order-notifications"
  kms_master_key_id = "alias/aws/sns"
  tags              = var.tags
}

resource "aws_sns_topic_subscription" "email" {
  for_each  = var.sns_email_subscriptions
  topic_arn = aws_sns_topic.orders.arn
  protocol  = "email"
  endpoint  = each.value
}
