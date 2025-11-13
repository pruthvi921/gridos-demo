variable "name" {
  description = "Name of the storage account (must be globally unique, 3-24 chars, lowercase alphanumeric)"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.name))
    error_message = "Storage account name must be 3-24 characters, lowercase letters and numbers only"
  }
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "account_tier" {
  description = "Storage account tier (Standard or Premium)"
  type        = string
  default     = "Standard"
  validation {
    condition     = contains(["Standard", "Premium"], var.account_tier)
    error_message = "Account tier must be Standard or Premium"
  }
}

variable "replication_type" {
  description = "Storage replication type (LRS, GRS, RAGRS, ZRS, GZRS, RAGZRS)"
  type        = string
  default     = "LRS"
  validation {
    condition     = contains(["LRS", "GRS", "RAGRS", "ZRS", "GZRS", "RAGZRS"], var.replication_type)
    error_message = "Invalid replication type"
  }
}

variable "account_kind" {
  description = "Storage account kind"
  type        = string
  default     = "StorageV2"
  validation {
    condition     = contains(["StorageV2", "BlobStorage", "BlockBlobStorage", "FileStorage"], var.account_kind)
    error_message = "Invalid account kind"
  }
}

variable "allow_public_access" {
  description = "Allow public access to blobs"
  type        = bool
  default     = false
}

variable "shared_access_key_enabled" {
  description = "Enable storage account key access"
  type        = bool
  default     = true
}

variable "network_rules" {
  description = "Network rules configuration"
  type = object({
    default_action             = string
    ip_rules                   = list(string)
    virtual_network_subnet_ids = list(string)
    bypass                     = list(string)
  })
  default = null
}

variable "enable_versioning" {
  description = "Enable blob versioning"
  type        = bool
  default     = false
}

variable "enable_soft_delete" {
  description = "Enable soft delete for blobs and containers"
  type        = bool
  default     = true
}

variable "soft_delete_retention_days" {
  description = "Number of days to retain soft-deleted items"
  type        = number
  default     = 7
  validation {
    condition     = var.soft_delete_retention_days >= 1 && var.soft_delete_retention_days <= 365
    error_message = "Retention days must be between 1 and 365"
  }
}

variable "create_tfstate_container" {
  description = "Create a tfstate container for Terraform remote state"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
