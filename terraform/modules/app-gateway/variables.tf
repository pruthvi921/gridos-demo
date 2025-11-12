# Application Gateway Module Variables

variable "environment" {
  description = "Environment name (dev, test, prod)"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for Application Gateway"
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID for diagnostics"
  type        = string
}

variable "zones" {
  description = "Availability zones for Application Gateway"
  type        = list(string)
  default     = ["1", "2", "3"]
}

variable "sku_name" {
  description = "SKU name for Application Gateway (Standard_v2 or WAF_v2)"
  type        = string
  default     = "WAF_v2"
}

variable "sku_tier" {
  description = "SKU tier for Application Gateway (Standard_v2 or WAF_v2)"
  type        = string
  default     = "WAF_v2"
}

variable "capacity" {
  description = "Fixed capacity for Application Gateway (ignored if autoscale enabled)"
  type        = number
  default     = 2
}

variable "enable_autoscale" {
  description = "Enable autoscaling for Application Gateway"
  type        = bool
  default     = true
}

variable "min_capacity" {
  description = "Minimum capacity for autoscaling"
  type        = number
  default     = 2
}

variable "max_capacity" {
  description = "Maximum capacity for autoscaling"
  type        = number
  default     = 10
}

variable "enable_waf" {
  description = "Enable WAF (Web Application Firewall)"
  type        = bool
  default     = true
}

variable "waf_mode" {
  description = "WAF mode (Detection or Prevention)"
  type        = string
  default     = "Prevention"

  validation {
    condition     = contains(["Detection", "Prevention"], var.waf_mode)
    error_message = "WAF mode must be either Detection or Prevention."
  }
}

variable "identity_ids" {
  description = "User assigned identity IDs for Application Gateway"
  type        = list(string)
  default     = null
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
