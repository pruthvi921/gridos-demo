# Production Environment - Variable Values
# This file contains environment-specific values for the production environment
# Azure Subscription: 1e371d35-9938-4d5c-94ef-a1b1f9d32e31

# Basic Configuration
environment  = "prod"
project_name = "gridos"
location     = "norwayeast"
cost_center  = "Operations"
owner        = "SRE-Team"

# Networking Configuration
vnet_address_space   = "10.2.0.0/16"
public_subnet_prefix = "10.2.1.0/24"
aks_subnet_prefix    = "10.2.10.0/22"
db_subnet_prefix     = "10.2.20.0/24"
enable_nat_gateway   = true

# Database Configuration (Production-grade with HA)
postgres_version               = "16"
postgres_sku_name              = "GP_Standard_D4s_v3" # Production tier
postgres_storage_mb            = 131072               # 128 GB
postgres_backup_retention_days = 35                   # 35 days retention
postgres_enable_ha             = true                 # High Availability enabled

# Kubernetes Configuration (Production scale)
kubernetes_version         = "1.28.3"
system_node_count          = 3 # 3 system nodes for HA
system_node_size           = "Standard_D4s_v3"
user_node_count            = 5  # Start with 5 user nodes
user_node_max_count        = 20 # Max 20 for production scale
user_node_size             = "Standard_D8s_v3"
enable_monitoring_nodepool = true # Dedicated monitoring pool

# Log Analytics Configuration
log_retention_days = 90 # 90 days retention for compliance

# Key Vault Configuration
key_vault_soft_delete_retention_days = 90
key_vault_purge_protection_enabled   = true # Purge protection in prod

# Container Registry Configuration
acr_sku           = "Premium" # Premium for geo-replication support
acr_admin_enabled = false

# Additional Tags
additional_tags = {
  Terraform      = "true"
  AutoShutdown   = "disabled" # Never auto-shutdown in prod
  BackupRequired = "true"
  Compliance     = "required"
  CriticalSystem = "true"
  SLA            = "99.9"
}
