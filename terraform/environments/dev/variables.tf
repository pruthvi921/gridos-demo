# Development Environment Variables

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"

  validation {
    condition     = can(regex("^(dev|test|prod)$", var.environment))
    error_message = "Environment must be dev, test, or prod."
  }
}

variable "project_name" {
  description = "Project name used in resource naming"
  type        = string
  default     = "gridos"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "norwayeast"
}

variable "cost_center" {
  description = "Cost center for billing"
  type        = string
  default     = "Engineering"
}

variable "owner" {
  description = "Owner team or person"
  type        = string
  default     = "SRE-Team"
}

# Networking Configuration
variable "vnet_address_space" {
  description = "Address space for the virtual network"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_prefix" {
  description = "Address prefix for public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "aks_subnet_prefix" {
  description = "Address prefix for AKS subnet"
  type        = string
  default     = "10.0.10.0/22"
}

variable "db_subnet_prefix" {
  description = "Address prefix for database subnet"
  type        = string
  default     = "10.0.20.0/24"
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnet outbound access"
  type        = bool
  default     = true
}

# Database Configuration
variable "postgres_version" {
  description = "PostgreSQL version"
  type        = string
  default     = "16"
}

variable "postgres_sku_name" {
  description = "SKU name for PostgreSQL server"
  type        = string
  default     = "B_Standard_B2s"
}

variable "postgres_storage_mb" {
  description = "Storage size in MB for PostgreSQL"
  type        = number
  default     = 32768 # 32 GB
}

variable "postgres_backup_retention_days" {
  description = "Backup retention in days"
  type        = number
  default     = 7
}

variable "postgres_enable_ha" {
  description = "Enable high availability for PostgreSQL"
  type        = bool
  default     = false
}

# Kubernetes Configuration
variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.28.3"
}

variable "system_node_count" {
  description = "Initial number of system nodes"
  type        = number
  default     = 1
}

variable "system_node_size" {
  description = "VM size for system nodes"
  type        = string
  default     = "Standard_B4ms"
}

variable "user_node_count" {
  description = "Initial number of user nodes"
  type        = number
  default     = 2
}

variable "user_node_max_count" {
  description = "Maximum number of user nodes for autoscaling"
  type        = number
  default     = 4
}

variable "user_node_size" {
  description = "VM size for user nodes"
  type        = string
  default     = "Standard_B4ms"
}

variable "enable_monitoring_nodepool" {
  description = "Enable dedicated node pool for monitoring workloads"
  type        = bool
  default     = false
}

# Log Analytics Configuration
variable "log_retention_days" {
  description = "Log retention in days"
  type        = number
  default     = 30
}

# Key Vault Configuration
variable "key_vault_soft_delete_retention_days" {
  description = "Soft delete retention days for Key Vault"
  type        = number
  default     = 7
}

variable "key_vault_purge_protection_enabled" {
  description = "Enable purge protection for Key Vault"
  type        = bool
  default     = false
}

# Container Registry Configuration
variable "acr_sku" {
  description = "SKU for Azure Container Registry"
  type        = string
  default     = "Standard"

  validation {
    condition     = can(regex("^(Basic|Standard|Premium)$", var.acr_sku))
    error_message = "ACR SKU must be Basic, Standard, or Premium."
  }
}

variable "acr_admin_enabled" {
  description = "Enable admin user for ACR"
  type        = bool
  default     = false
}

# Application Gateway Configuration
variable "appgw_sku_name" {
  description = "SKU name for Application Gateway"
  type        = string
  default     = "Standard_v2"
}

variable "appgw_sku_tier" {
  description = "SKU tier for Application Gateway"
  type        = string
  default     = "Standard_v2"
}

variable "appgw_capacity" {
  description = "Fixed capacity for Application Gateway (ignored if autoscale enabled)"
  type        = number
  default     = 2
}

variable "appgw_enable_autoscale" {
  description = "Enable autoscaling for Application Gateway"
  type        = bool
  default     = false
}

variable "appgw_min_capacity" {
  description = "Minimum capacity for autoscaling"
  type        = number
  default     = 2
}

variable "appgw_max_capacity" {
  description = "Maximum capacity for autoscaling"
  type        = number
  default     = 5
}

variable "appgw_enable_waf" {
  description = "Enable WAF (Web Application Firewall)"
  type        = bool
  default     = false
}

variable "appgw_waf_mode" {
  description = "WAF mode (Detection or Prevention)"
  type        = string
  default     = "Detection"
}

variable "appgw_zones" {
  description = "Availability zones for Application Gateway"
  type        = list(string)
  default     = []
}

# Tags
variable "additional_tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}
