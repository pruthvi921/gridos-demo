# Azure Storage Account Module

resource "azurerm_storage_account" "this" {
  name                     = var.name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = var.account_tier
  account_replication_type = var.replication_type
  account_kind             = var.account_kind

  # Security features
  enable_https_traffic_only       = true
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = var.allow_public_access
  shared_access_key_enabled       = var.shared_access_key_enabled

  # Network rules
  dynamic "network_rules" {
    for_each = var.network_rules != null ? [var.network_rules] : []
    content {
      default_action             = network_rules.value.default_action
      ip_rules                   = network_rules.value.ip_rules
      virtual_network_subnet_ids = network_rules.value.virtual_network_subnet_ids
      bypass                     = network_rules.value.bypass
    }
  }

  # Blob properties
  dynamic "blob_properties" {
    for_each = var.enable_versioning || var.enable_soft_delete ? [1] : []
    content {
      versioning_enabled = var.enable_versioning

      dynamic "delete_retention_policy" {
        for_each = var.enable_soft_delete ? [1] : []
        content {
          days = var.soft_delete_retention_days
        }
      }

      dynamic "container_delete_retention_policy" {
        for_each = var.enable_soft_delete ? [1] : []
        content {
          days = var.soft_delete_retention_days
        }
      }
    }
  }

  tags = var.tags
}

# Storage Container for Terraform State
resource "azurerm_storage_container" "tfstate" {
  count                 = var.create_tfstate_container ? 1 : 0
  name                  = "tfstate"
  storage_account_name  = azurerm_storage_account.this.name
  container_access_type = "private"
}
