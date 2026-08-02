variable "aws_region" {
  type    = string
  default = "ca-central-1"
}
variable "allow_main_region_deployment" {
  type        = bool
  description = "Explicit safety switch for a later deployment in the existing main region."
  default     = false
}
variable "enable_enterprise_backup" {
  type        = bool
  description = "Creates AWS Backup vaults, plan, selection, and cross-region copy policy."
  default     = false
}
variable "backup_operator_user_name" {
  type        = string
  description = "Existing IAM user allowed to operate the Eatinity backup, copy, and restore workflow."
}
variable "source_aws_region" {
  type    = string
  default = "us-east-1"
}
variable "source_table_names" {
  type = map(string)
  default = {
    products   = "EatinityProducts"
    categories = "EatinityCategories"
    orders     = "EatinityOrders"
    audit      = "EatinityAuditLog"
    users      = "EatinityUsers"
  }
}
variable "source_bucket_names" {
  type = map(string)
  default = {
    images  = "eatinity-prod-s3-images"
    website = "eatinity-prod-s3-website"
  }
}
variable "source_cognito_user_pool_id" {
  type    = string
  default = "us-east-1_4hyzIbJTa"
}
variable "backup_schedule_expression" {
  type    = string
  default = "cron(0 5 ? * * *)"
}
variable "source_backup_retention_days" {
  type    = number
  default = 35
}
variable "recovery_backup_retention_days" {
  type    = number
  default = 90
}
variable "project_name" {
  type    = string
  default = "eatinity"
}
variable "environment" {
  type    = string
  default = "prod"

  validation {
    condition     = var.environment == "prod"
    error_message = "This production-style root requires environment = prod."
  }
}
variable "disposable_environment" {
  type        = bool
  description = "False for protected recovery validation; enable only during an explicitly approved teardown."
  default     = false
}
variable "domain_name" {
  type    = string
  default = "eatinity.ca"
}
variable "allowed_origins" {
  type    = list(string)
  default = ["http://localhost:3000", "http://localhost:5173"]
}

variable "create_cognito_resources" {
  type    = bool
  default = true
}
variable "existing_cognito_user_pool_id" {
  type    = string
  default = null
}
variable "existing_cognito_client_id" {
  type    = string
  default = null
}
variable "cognito_callback_urls" {
  type    = list(string)
  default = ["http://localhost:3000", "http://localhost:5173"]
}
variable "cognito_logout_urls" {
  type    = list(string)
  default = ["http://localhost:3000", "http://localhost:5173"]
}

variable "enable_point_in_time_recovery" {
  type    = bool
  default = true
}
variable "enable_deletion_protection" {
  type    = bool
  default = true
}
variable "enable_s3_versioning" {
  type    = bool
  default = true
}
variable "force_destroy_buckets" {
  type    = bool
  default = false
}
variable "cloudwatch_log_retention_days" {
  type    = number
  default = 30
}

variable "use_custom_domain" {
  type    = bool
  default = false
}
variable "acm_certificate_arn" {
  type    = string
  default = null
}

variable "cloudfront_web_acl_arn" {
  description = "ARN of the existing us-east-1 WAFv2 web ACL for CloudFront"
  type        = string
  default     = null
}
variable "manage_public_dns" {
  type    = bool
  default = false
}
variable "enable_ses" {
  type    = bool
  default = false
}
variable "manage_ses_dns" {
  type        = bool
  description = "Creates only SES verification, DKIM, and MAIL FROM records in the existing Route 53 zone."
  default     = false
}
variable "ses_notification_emails" {
  type    = set(string)
  default = []
}
variable "ses_sandbox_recipient_emails" {
  type        = set(string)
  description = "Recipient addresses to verify for recovery testing while the destination SES region remains in the sandbox."
  default     = []
}
variable "ses_from_email" {
  type    = string
  default = "orders@eatinity.ca"
}
variable "sns_email_subscriptions" {
  type    = set(string)
  default = []
}

variable "secret_recovery_window_days" {
  type        = number
  description = "Recovery window for the Secrets Manager secret."
  default     = 7
}
