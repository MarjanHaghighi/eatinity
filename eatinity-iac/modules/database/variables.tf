variable "table_names" {
  type = object({ products = string, categories = string, orders = string, audit = string, users = string })
}
variable "enable_point_in_time_recovery" { type = bool }
variable "enable_deletion_protection" { type = bool }
variable "tags" {
  type    = map(string)
  default = {}
}
