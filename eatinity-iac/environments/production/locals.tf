locals {
  region_parts = split("-", var.aws_region)
  region_code = length(local.region_parts) == 3 ? format(
    "%s%s%s",
    local.region_parts[0],
    substr(local.region_parts[1], 0, 1),
    local.region_parts[2]
  ) : replace(var.aws_region, "-", "")
  resource_prefix = "${var.project_name}-${var.environment}-${local.region_code}"
  account_id      = data.aws_caller_identity.current.account_id

  website_bucket_name = "${local.resource_prefix}-${local.account_id}-website"
  images_bucket_name  = "${local.resource_prefix}-${local.account_id}-images"

  table_names = {
    products   = "${local.resource_prefix}-products"
    categories = "${local.resource_prefix}-categories"
    orders     = "${local.resource_prefix}-orders"
    audit      = "${local.resource_prefix}-audit"
    users      = "${local.resource_prefix}-users"
  }

  common_tags = {
    Project     = "Eatinity"
    Environment = var.environment
    RegionCode  = local.region_code
    Stack       = local.resource_prefix
    Purpose     = "DisasterRecoveryValidation"
    ManagedBy   = "Terraform"
    Disposable  = tostring(var.disposable_environment)
    Owner       = "Marjan Haghighi"
  }
}
