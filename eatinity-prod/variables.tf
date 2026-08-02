variable "aws_region" {
  default = "us-east-1"
}

variable "project_name" {
  default = "eatinity"
}

variable "images_bucket_name" {
  default = "eatinity-prod-s3-images"
}

variable "website_bucket_name" {
  default = "eatinity-prod-s3-website"
}

variable "iam_user_name" {
  description = "IAM user that manages Eatinity resources"
  type        = string
  default     = "marjan-admin"
}

variable "domain_name" {
  default = "eatinity.ca"
}

variable "www_domain_name" {
  default = "www.eatinity.ca"
}