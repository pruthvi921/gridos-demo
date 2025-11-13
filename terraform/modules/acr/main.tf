# Azure Container Registry Module

resource "azurerm_container_registry" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.sku
  admin_enabled       = var.admin_enabled

  # Network rules
  dynamic "network_rule_set" {
    for_each = var.network_rule_set != null ? [var.network_rule_set] : []
    content {
      default_action = network_rule_set.value.default_action

      dynamic "ip_rule" {
        for_each = network_rule_set.value.ip_rules
        content {
          action   = "Allow"
          ip_range = ip_rule.value
        }
      }

      dynamic "virtual_network" {
        for_each = network_rule_set.value.virtual_network_subnet_ids
        content {
          action    = "Allow"
          subnet_id = virtual_network.value
        }
      }
    }
  }

  # Geo-replication (Premium SKU only)
  dynamic "georeplications" {
    for_each = var.sku == "Premium" && var.geo_replication_locations != null ? var.geo_replication_locations : []
    content {
      location                = georeplications.value
      zone_redundancy_enabled = true
      tags                    = var.tags
    }
  }

  # Security features
  quarantine_policy_enabled = var.quarantine_policy_enabled

  tags = var.tags
}
