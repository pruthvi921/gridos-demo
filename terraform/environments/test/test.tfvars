# Test Environment - Variable Values
# This file contains environment-specific values for the test environment
# Azure Subscription: 1e371d35-9938-4d5c-94ef-a1b1f9d32e31

# Basic Configuration
environment  = "test"
project_name = "gridos"
location     = "norwayeast"
cost_center  = "Engineering"
owner        = "SRE-Team"

# Networking Configuration
vnet_address_space   = "10.1.0.0/16"
public_subnet_prefix = "10.1.1.0/24"
aks_subnet_prefix    = "10.1.10.0/22"
db_subnet_prefix     = "10.1.20.0/24"
enable_nat_gateway   = true

# Database Configuration (More robust than dev)
postgres_version               = "16"
postgres_sku_name              = "GP_Standard_D2s_v3" # General Purpose tier
postgres_storage_mb            = 65536                # 64 GB
postgres_backup_retention_days = 14                   # 2 weeks retention
postgres_enable_ha             = false                # Still no HA in test

# Kubernetes Configuration (Larger than dev, smaller than prod)
kubernetes_version         = "1.28.3"
system_node_count          = 2 # 2 system nodes for reliability
system_node_size           = "Standard_D4s_v3"
user_node_count            = 3 # Start with 3 user nodes
user_node_max_count        = 6 # Max 6 for moderate scale testing
user_node_size             = "Standard_D4s_v3"
enable_monitoring_nodepool = true # Enable monitoring in test

# Log Analytics Configuration
log_retention_days = 60 # 60 days retention for testing analysis

# Key Vault Configuration
key_vault_soft_delete_retention_days = 30
key_vault_purge_protection_enabled   = false

# Container Registry Configuration
acr_sku           = "Standard"
acr_admin_enabled = false

# Additional Tags
additional_tags = {
  Terraform       = "true"
  AutoShutdown    = "enabled"
  BackupRequired  = "true"
  TestEnvironment = "true"
}
