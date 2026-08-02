variable "resource_prefix" { type = string }
variable "aws_region" { type = string }
variable "api_name" { type = string }
variable "allowed_origins" { type = list(string) }
variable "cognito_user_pool_id" { type = string }
variable "cognito_user_pool_arn" { type = string }
variable "cognito_client_id" { type = string }
variable "table_names" { type = object({ products = string, categories = string, orders = string, audit = string, users = string }) }
variable "table_arns" { type = object({ products = string, categories = string, orders = string, audit = string, users = string }) }
variable "images_bucket" { type = object({ id = string, arn = string, domain = string, name = string }) }
variable "sns_topic_arn" { type = string }
variable "ses_from_email" { type = string }
variable "stripe_secret_arn" { type = string }
variable "frontend_success_url" { type = string }
variable "frontend_cancel_url" { type = string }
variable "log_retention_days" { type = number }
variable "tags" {
  type    = map(string)
  default = {}
}
