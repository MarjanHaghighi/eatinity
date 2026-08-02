variable "resource_prefix" { type = string }
variable "website_bucket" { type = object({ id = string, arn = string, domain = string, name = string }) }
variable "domain_name" { type = string }
variable "use_custom_domain" { type = bool }
variable "acm_certificate_arn" {
  type    = string
  default = null
}
variable "manage_public_dns" { type = bool }
variable "aws_region" { type = string }
variable "web_acl_arn" {
  description = "ARN of the us-east-1 WAFv2 web ACL protecting CloudFront"
  type        = string
}
variable "tags" {
  type    = map(string)
  default = {}
}
