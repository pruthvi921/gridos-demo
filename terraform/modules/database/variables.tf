variable "environment" {
  description = "Environment name (dev, test, prod)"
  type        = string
}

variable "project_name" {
  description = "Project name used in resource naming"
  type        = string
  default     = "gridos"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "subnet_id" {
  description = "ID of the subnet for database"
  type        = string
}

variable "private_dns_zone_id" {
  description = "ID of the private DNS zone"
  type        = string
}

variable "key_vault_id" {
  description = "ID of the Key Vault for storing secrets"
  type        = string
  default     = ""
}

variable "postgres_version" {
  description = "PostgreSQL version"
  type        = string
  default     = "16"
}

variable "admin_username" {
  description = "Administrator username"
  type        = string
  default     = "psqladmin"
}

variable "sku_name" {
  description = "SKU name for PostgreSQL server"
  type        = string
  default     = "GP_Standard_D4s_v3"
}

variable "storage_mb" {
  description = "Storage size in MB"
  type        = number
  default     = 131072 # 128 GB
}

variable "storage_tier" {
  description = "Storage tier"
  type        = string
  default     = "P30"
}

variable "backup_retention_days" {
  description = "Backup retention in days"
  type        = number
  default     = 7
}

variable "enable_high_availability" {
  description = "Enable high availability"
  type        = bool
  default     = false
}

variable "zone" {
  description = "Availability zone for primary server"
  type        = string
  default     = "1"
}

variable "standby_zone" {
  description = "Availability zone for standby server"
  type        = string
  default     = "2"
}

variable "max_connections" {
  description = "Maximum number of connections"
  type        = string
  default     = "500"
}

variable "shared_buffers" {
  description = "Shared buffers size"
  type        = string
  default     = "524288" # 4GB in 8KB blocks
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
