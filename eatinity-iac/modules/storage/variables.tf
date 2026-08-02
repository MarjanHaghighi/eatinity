variable "website_bucket_name" { type = string }
variable "images_bucket_name" { type = string }
variable "enable_versioning" { type = bool }
variable "force_destroy" { type = bool }
variable "tags" {
  type    = map(string)
  default = {}
}
