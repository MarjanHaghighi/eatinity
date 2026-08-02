variable "resource_prefix" { type = string }
variable "create_user_pool" { type = bool }
variable "enable_deletion_protection" { type = bool }
variable "existing_user_pool_id" {
  type    = string
  default = null
}
variable "existing_user_pool_client_id" {
  type    = string
  default = null
}
variable "callback_urls" {
  type    = list(string)
  default = []
}
variable "logout_urls" {
  type    = list(string)
  default = []
}
variable "tags" {
  type    = map(string)
  default = {}
}
