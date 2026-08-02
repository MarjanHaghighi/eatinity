resource "aws_dynamodb_table" "products" {
  name                        = var.table_names.products
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = "id"
  deletion_protection_enabled = var.enable_deletion_protection

  attribute {
    name = "id"
    type = "S"
  }
  attribute {
    name = "category"
    type = "S"
  }
  attribute {
    name = "displayOrder"
    type = "N"
  }
  global_secondary_index {
    name            = "category-displayOrder-index"
    projection_type = "ALL"

    key_schema {
      attribute_name = "category"
      key_type       = "HASH"
    }

    key_schema {
      attribute_name = "displayOrder"
      key_type       = "RANGE"
    }
  }
  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }
  tags = var.tags
}

resource "aws_dynamodb_table" "categories" {
  name                        = var.table_names.categories
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = "categoryId"
  deletion_protection_enabled = var.enable_deletion_protection
  attribute {
    name = "categoryId"
    type = "S"
  }
  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }
  tags = var.tags
}

resource "aws_dynamodb_table" "orders" {
  name                        = var.table_names.orders
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = "orderId"
  deletion_protection_enabled = var.enable_deletion_protection
  attribute {
    name = "orderId"
    type = "S"
  }
  attribute {
    name = "userId"
    type = "S"
  }
  attribute {
    name = "orderStatus"
    type = "S"
  }
  attribute {
    name = "createdAt"
    type = "S"
  }
  attribute {
    name = "paymentStatus"
    type = "S"
  }
  attribute {
    name = "paidAt"
    type = "S"
  }
  global_secondary_index {
    name            = "userId-index"
    projection_type = "ALL"

    key_schema {
      attribute_name = "userId"
      key_type       = "HASH"
    }
  }
  global_secondary_index {
    name            = "orderStatus-createdAt-index"
    projection_type = "ALL"

    key_schema {
      attribute_name = "orderStatus"
      key_type       = "HASH"
    }

    key_schema {
      attribute_name = "createdAt"
      key_type       = "RANGE"
    }
  }
  global_secondary_index {
    name            = "paymentStatus-paidAt-index"
    projection_type = "ALL"

    key_schema {
      attribute_name = "paymentStatus"
      key_type       = "HASH"
    }

    key_schema {
      attribute_name = "paidAt"
      key_type       = "RANGE"
    }
  }
  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }
  tags = var.tags
}

resource "aws_dynamodb_table" "audit" {
  name                        = var.table_names.audit
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = "auditId"
  deletion_protection_enabled = var.enable_deletion_protection
  attribute {
    name = "auditId"
    type = "S"
  }
  attribute {
    name = "entityId"
    type = "S"
  }
  attribute {
    name = "createdAt"
    type = "S"
  }
  attribute {
    name = "scope"
    type = "S"
  }
  global_secondary_index {
    name            = "entityId-createdAt-index"
    projection_type = "ALL"

    key_schema {
      attribute_name = "entityId"
      key_type       = "HASH"
    }

    key_schema {
      attribute_name = "createdAt"
      key_type       = "RANGE"
    }
  }
  global_secondary_index {
    name            = "scope-createdAt-index"
    projection_type = "ALL"

    key_schema {
      attribute_name = "scope"
      key_type       = "HASH"
    }

    key_schema {
      attribute_name = "createdAt"
      key_type       = "RANGE"
    }
  }
  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }
  tags = var.tags
}

resource "aws_dynamodb_table" "users" {
  name                        = var.table_names.users
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = "userId"
  deletion_protection_enabled = var.enable_deletion_protection
  attribute {
    name = "userId"
    type = "S"
  }
  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }
  tags = var.tags
}
