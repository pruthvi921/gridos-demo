# Development Environment - Variable Values
# This file contains environment-specific values for the dev environment
# Azure Subscription: 1e371d35-9938-4d5c-94ef-a1b1f9d32e31

# Basic Configuration
environment  = "dev"
project_name = "gridos"
location     = "norwayeast"
cost_center  = "Engineering"
owner        = "SRE-Team"

# Networking Configuration
vnet_address_space   = "10.0.0.0/16"
public_subnet_prefix = "10.0.1.0/24"
aks_subnet_prefix    = "10.0.10.0/22"
db_subnet_prefix     = "10.0.20.0/24"
enable_nat_gateway   = true

# Database Configuration (Optimized for Dev - Lower Cost)
postgres_version               = "16"
postgres_sku_name              = "B_Standard_B2s" # Burstable tier for cost savings
postgres_storage_mb            = 32768            # 32 GB
postgres_backup_retention_days = 7                # Minimum retention
postgres_enable_ha             = false            # No HA in dev

# Kubernetes Configuration (Optimized for Dev - Smaller Scale)
kubernetes_version         = "1.28.3"
system_node_count          = 1 # Minimal system nodes
system_node_size           = "Standard_B4ms"
user_node_count            = 2 # Start with 2 user nodes
user_node_max_count        = 4 # Max 4 for cost control
user_node_size             = "Standard_B4ms"
enable_monitoring_nodepool = false # No dedicated monitoring pool in dev

# Log Analytics Configuration
log_retention_days = 30 # 30 days retention

# Key Vault Configuration
key_vault_soft_delete_retention_days = 7
key_vault_purge_protection_enabled   = false # Easier cleanup in dev

# Container Registry Configuration
acr_sku           = "Standard"
acr_admin_enabled = false

# Additional Tags
additional_tags = {
  Terraform      = "true"
  AutoShutdown   = "enabled" # Tag for cost management
  BackupRequired = "false"
}
