# Development Environment Configuration

locals {
  common_tags = merge(
    {
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "Terraform"
      CostCenter  = var.cost_center
      Owner       = var.owner
    },
    var.additional_tags
  )
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = "${var.environment}-${var.project_name}-rg"
  location = var.location
  tags     = local.common_tags
}

# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "main" {
  name                = "${var.environment}-${var.project_name}-logs"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days

  tags = local.common_tags
}

# Container Registry Module
module "acr" {
  source = "../../modules/acr"

  name                = "${var.project_name}acr"  # gridosacr
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = var.acr_sku
  admin_enabled       = var.acr_admin_enabled

  tags = local.common_tags
}

# Key Vault Module (for application secrets)
data "azurerm_client_config" "current" {}

module "key_vault" {
  source = "../../modules/key-vault"

  name                = "${var.environment}-${var.project_name}-kv"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku_name            = "standard"

  soft_delete_retention_days = var.key_vault_soft_delete_retention_days
  purge_protection_enabled   = var.key_vault_purge_protection_enabled

  access_policies = [
    {
      object_id = data.azurerm_client_config.current.object_id
      secret_permissions = [
        "Get", "List", "Set", "Delete", "Recover", "Backup", "Restore", "Purge"
      ]
    }
  ]

  tags = local.common_tags
}

# Networking Module
module "networking" {
  source = "../../modules/networking"

  environment         = var.environment
  project_name        = var.project_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  vnet_address_space   = var.vnet_address_space
  public_subnet_prefix = var.public_subnet_prefix
  aks_subnet_prefix    = var.aks_subnet_prefix
  db_subnet_prefix     = var.db_subnet_prefix
  enable_nat_gateway   = var.enable_nat_gateway

  tags = local.common_tags
}

# Database Module
module "database" {
  source = "../../modules/database"

  environment         = var.environment
  project_name        = var.project_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = module.networking.db_subnet_id
  private_dns_zone_id = module.networking.private_dns_zone_id
  key_vault_id        = module.key_vault.id

  postgres_version         = var.postgres_version
  sku_name                 = var.postgres_sku_name
  storage_mb               = var.postgres_storage_mb
  backup_retention_days    = var.postgres_backup_retention_days
  enable_high_availability = var.postgres_enable_ha

  tags = local.common_tags

  depends_on = [module.networking]
}

# Kubernetes Module
module "kubernetes" {
  source = "../../modules/kubernetes"

  environment                = var.environment
  project_name               = var.project_name
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  subnet_id                  = module.networking.aks_subnet_id
  vnet_id                    = module.networking.vnet_id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  container_registry_id      = module.acr.id

  kubernetes_version         = var.kubernetes_version
  system_node_count          = var.system_node_count
  system_node_size           = var.system_node_size
  user_node_count            = var.user_node_count
  user_node_max_count        = var.user_node_max_count
  user_node_size             = var.user_node_size
  enable_monitoring_nodepool = var.enable_monitoring_nodepool

  tags = local.common_tags

  depends_on = [module.networking]
}

# Application Gateway Module
module "app_gateway" {
  source = "../../modules/app-gateway"

  environment                = var.environment
  project_name               = var.project_name
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  subnet_id                  = module.networking.appgw_subnet_id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  sku_name         = var.appgw_sku_name
  sku_tier         = var.appgw_sku_tier
  capacity         = var.appgw_capacity
  enable_autoscale = var.appgw_enable_autoscale
  min_capacity     = var.appgw_min_capacity
  max_capacity     = var.appgw_max_capacity
  enable_waf       = var.appgw_enable_waf
  waf_mode         = var.appgw_waf_mode
  zones            = var.appgw_zones

  tags = local.common_tags

  depends_on = [module.networking]
}

# Allow AKS to access Key Vault for application secrets
resource "azurerm_key_vault_access_policy" "aks" {
  key_vault_id = module.key_vault.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = module.kubernetes.kubelet_identity_object_id

  secret_permissions = [
    "Get", "List"
  ]
}
