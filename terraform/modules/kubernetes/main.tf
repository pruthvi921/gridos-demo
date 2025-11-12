# Azure Kubernetes Service (AKS) Module
# Production-ready AKS cluster with auto-scaling and monitoring

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
  }
}

# AKS Cluster
resource "azurerm_kubernetes_cluster" "main" {
  name                = "${var.environment}-${var.project_name}-aks"
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = "${var.environment}-${var.project_name}"
  kubernetes_version  = var.kubernetes_version

  # Enable RBAC and Azure AD integration
  azure_active_directory_role_based_access_control {
    managed            = true
    azure_rbac_enabled = true
  }

  # Default node pool for system components
  default_node_pool {
    name                = "system"
    node_count          = var.system_node_count
    vm_size             = var.system_node_size
    vnet_subnet_id      = var.subnet_id
    enable_auto_scaling = true
    min_count           = var.system_node_count
    max_count           = var.system_node_count * 2
    max_pods            = 110
    os_disk_size_gb     = 128
    os_disk_type        = "Managed"

    upgrade_settings {
      max_surge = "33%"
    }

    node_labels = {
      "nodepool-type" = "system"
      "environment"   = var.environment
      "nodepoolos"    = "linux"
    }

    tags = merge(
      var.tags,
      {
        "nodepool-type" = "system"
      }
    )
  }

  # Managed identity for AKS
  identity {
    type = "SystemAssigned"
  }

  # Network configuration
  network_profile {
    network_plugin    = "azure"
    network_policy    = "azure"
    dns_service_ip    = "10.2.0.10"
    service_cidr      = "10.2.0.0/16"
    load_balancer_sku = "standard"
    outbound_type     = "userDefinedRouting"
  }

  # Enable monitoring
  oms_agent {
    log_analytics_workspace_id = var.log_analytics_workspace_id
  }

  # Enable Azure Policy Add-on
  azure_policy_enabled = true

  # HTTP application routing (disabled for production)
  http_application_routing_enabled = false

  # Key Vault Secrets Provider
  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }

  # Maintenance window
  maintenance_window {
    allowed {
      day   = "Sunday"
      hours = [2, 3, 4]
    }
  }

  # Auto-upgrade channel
  automatic_channel_upgrade = var.environment == "prod" ? "stable" : "rapid"

  tags = merge(
    var.tags,
    {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Module      = "kubernetes"
    }
  )

  lifecycle {
    ignore_changes = [
      default_node_pool[0].node_count
    ]
  }
}

# User node pool for application workloads
resource "azurerm_kubernetes_cluster_node_pool" "user" {
  name                  = "user"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = var.user_node_size
  vnet_subnet_id        = var.subnet_id

  enable_auto_scaling = true
  node_count          = var.user_node_count
  min_count           = var.user_node_count
  max_count           = var.user_node_max_count
  max_pods            = 110
  os_disk_size_gb     = 128
  os_disk_type        = "Managed"

  node_labels = {
    "nodepool-type" = "user"
    "environment"   = var.environment
    "workload"      = "application"
  }

  node_taints = []

  upgrade_settings {
    max_surge = "33%"
  }

  tags = merge(
    var.tags,
    {
      "nodepool-type" = "user"
    }
  )

  lifecycle {
    ignore_changes = [
      node_count
    ]
  }
}

# Monitoring node pool for observability stack
resource "azurerm_kubernetes_cluster_node_pool" "monitoring" {
  count                 = var.enable_monitoring_nodepool ? 1 : 0
  name                  = "monitoring"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = var.monitoring_node_size
  vnet_subnet_id        = var.subnet_id

  enable_auto_scaling = false
  node_count          = 2
  max_pods            = 50
  os_disk_size_gb     = 256
  os_disk_type        = "Managed"

  node_labels = {
    "nodepool-type" = "monitoring"
    "environment"   = var.environment
    "workload"      = "observability"
  }

  node_taints = [
    "workload=observability:NoSchedule"
  ]

  tags = merge(
    var.tags,
    {
      "nodepool-type" = "monitoring"
    }
  )
}

# Role assignment for AKS to pull images from ACR
resource "azurerm_role_assignment" "aks_acr" {
  count                = var.container_registry_id != "" ? 1 : 0
  principal_id         = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
  role_definition_name = "AcrPull"
  scope                = var.container_registry_id
}

# Role assignment for AKS to manage network resources
resource "azurerm_role_assignment" "aks_network" {
  principal_id         = azurerm_kubernetes_cluster.main.identity[0].principal_id
  role_definition_name = "Network Contributor"
  scope                = var.vnet_id
}
