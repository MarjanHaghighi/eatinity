variable "aws_region" {
  type    = string
  default = "ca-central-1"
}
variable "github_owner" {
  type        = string
  description = "GitHub user or organization that owns the repository."
}
variable "github_repository" {
  type        = string
  description = "Repository name without the owner prefix."
}
variable "github_environment" {
  type        = string
  description = "Protected GitHub Environment allowed to deploy."
  default     = "production"
}
variable "resource_prefix" {
  type    = string
  default = "eatinity"
}
variable "terraform_state_bucket_arn" {
  type        = string
  description = "ARN of the separately managed Terraform state bucket."
}

