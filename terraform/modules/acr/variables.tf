variable "name" {
  description = "Name of the Container Registry"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "sku" {
  description = "SKU tier (Basic, Standard, Premium)"
  type        = string
  default     = "Standard"
  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.sku)
    error_message = "SKU must be Basic, Standard, or Premium"
  }
}

variable "admin_enabled" {
  description = "Enable admin user (use managed identities in production)"
  type        = bool
  default     = false
}

variable "network_rule_set" {
  description = "Network rules configuration"
  type = object({
    default_action               = string
    ip_rules                     = list(string)
    virtual_network_subnet_ids   = list(string)
  })
  default = null
}

variable "geo_replication_locations" {
  description = "List of regions for geo-replication (Premium SKU only)"
  type        = list(string)
  default     = null
}

variable "quarantine_policy_enabled" {
  description = "Enable quarantine policy for security scanning"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
