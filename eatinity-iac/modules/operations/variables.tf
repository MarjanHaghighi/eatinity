variable "resource_prefix" { type = string }
variable "enable_ses" { type = bool }
variable "ses_domain" { type = string }
variable "manage_ses_dns" { type = bool }
variable "ses_route53_zone_id" {
  type    = string
  default = null
}
variable "ses_notification_emails" {
  type    = set(string)
  default = []
}
variable "ses_sandbox_recipient_emails" {
  type    = set(string)
  default = []
}
variable "sns_email_subscriptions" {
  type    = set(string)
  default = []
}
variable "tags" {
  type    = map(string)
  default = {}
}
