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
  description = "ID of the subnet for AKS nodes"
  type        = string
}

variable "vnet_id" {
  description = "ID of the virtual network"
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "ID of the Log Analytics workspace for monitoring"
  type        = string
}

variable "container_registry_id" {
  description = "ID of the Azure Container Registry"
  type        = string
  default     = ""
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.28.3"
}

variable "system_node_count" {
  description = "Initial number of system nodes"
  type        = number
  default     = 2
}

variable "system_node_size" {
  description = "VM size for system nodes"
  type        = string
  default     = "Standard_D4s_v3"
}

variable "user_node_count" {
  description = "Initial number of user nodes"
  type        = number
  default     = 3
}

variable "user_node_max_count" {
  description = "Maximum number of user nodes for autoscaling"
  type        = number
  default     = 10
}

variable "user_node_size" {
  description = "VM size for user nodes"
  type        = string
  default     = "Standard_D8s_v3"
}

variable "enable_monitoring_nodepool" {
  description = "Enable dedicated node pool for monitoring"
  type        = bool
  default     = false
}

variable "monitoring_node_size" {
  description = "VM size for monitoring nodes"
  type        = string
  default     = "Standard_D4s_v3"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
