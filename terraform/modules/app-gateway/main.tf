# Azure Application Gateway Module
# Production-ready Application Gateway with WAF for canary deployments

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
  }
}

# Public IP for Application Gateway
resource "azurerm_public_ip" "appgw" {
  name                = "${var.environment}-${var.project_name}-appgw-pip"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = var.zones

  tags = merge(
    var.tags,
    {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Module      = "app-gateway"
    }
  )
}

# Application Gateway with WAF v2
resource "azurerm_application_gateway" "main" {
  name                = "${var.environment}-${var.project_name}-appgw"
  resource_group_name = var.resource_group_name
  location            = var.location
  zones               = var.zones

  # SKU Configuration
  sku {
    name     = var.sku_name # Standard_v2 or WAF_v2
    tier     = var.sku_tier # Standard_v2 or WAF_v2
    capacity = var.capacity # 1-125 (autoscale if using)
  }

  # Gateway IP Configuration
  gateway_ip_configuration {
    name      = "appgw-ip-config"
    subnet_id = var.subnet_id
  }

  # Frontend Port (HTTP)
  frontend_port {
    name = "http-port"
    port = 80
  }

  # Frontend Port (HTTPS)
  frontend_port {
    name = "https-port"
    port = 443
  }

  # Frontend IP Configuration (Public)
  frontend_ip_configuration {
    name                 = "appgw-frontend-ip"
    public_ip_address_id = azurerm_public_ip.appgw.id
  }

  # Backend Address Pool (managed by AGIC)
  backend_address_pool {
    name = "default-backend-pool"
  }

  # Backend HTTP Settings
  backend_http_settings {
    name                  = "default-http-settings"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 30
    probe_name            = "default-health-probe"

    connection_draining {
      enabled           = true
      drain_timeout_sec = 60
    }
  }

  # Health Probe
  probe {
    name                                      = "default-health-probe"
    protocol                                  = "Http"
    path                                      = "/health"
    interval                                  = 30
    timeout                                   = 30
    unhealthy_threshold                       = 3
    pick_host_name_from_backend_http_settings = false
    host                                      = "127.0.0.1"

    match {
      status_code = ["200-399"]
      body        = ""
    }
  }

  # HTTP Listener
  http_listener {
    name                           = "http-listener"
    frontend_ip_configuration_name = "appgw-frontend-ip"
    frontend_port_name             = "http-port"
    protocol                       = "Http"
  }

  # Request Routing Rule
  request_routing_rule {
    name                       = "default-routing-rule"
    rule_type                  = "Basic"
    http_listener_name         = "http-listener"
    backend_address_pool_name  = "default-backend-pool"
    backend_http_settings_name = "default-http-settings"
    priority                   = 100
  }

  # WAF Configuration (if WAF_v2 tier)
  dynamic "waf_configuration" {
    for_each = var.enable_waf ? [1] : []
    content {
      enabled                  = true
      firewall_mode            = var.waf_mode # Detection or Prevention
      rule_set_type            = "OWASP"
      rule_set_version         = "3.2"
      file_upload_limit_mb     = 100
      max_request_body_size_kb = 128

      disabled_rule_group {
        rule_group_name = "REQUEST-920-PROTOCOL-ENFORCEMENT"
        rules           = []
      }
    }
  }

  # Autoscale Configuration
  dynamic "autoscale_configuration" {
    for_each = var.enable_autoscale ? [1] : []
    content {
      min_capacity = var.min_capacity
      max_capacity = var.max_capacity
    }
  }

  # Enable HTTP2
  enable_http2 = true

  # Managed Identity for Key Vault access (SSL certificates)
  identity {
    type = "UserAssigned"
    identity_ids = var.identity_ids != null ? var.identity_ids : [
      azurerm_user_assigned_identity.appgw.id
    ]
  }

  tags = merge(
    var.tags,
    {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Module      = "app-gateway"
    }
  )

  lifecycle {
    ignore_changes = [
      backend_address_pool,
      backend_http_settings,
      frontend_port,
      http_listener,
      probe,
      request_routing_rule,
      url_path_map,
      tags["kubernetes-ingress-controller"]
    ]
  }
}

# Managed Identity for Application Gateway
resource "azurerm_user_assigned_identity" "appgw" {
  count               = var.identity_ids == null ? 1 : 0
  name                = "${var.environment}-${var.project_name}-appgw-identity"
  resource_group_name = var.resource_group_name
  location            = var.location

  tags = merge(
    var.tags,
    {
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  )
}

# Diagnostic Settings
resource "azurerm_monitor_diagnostic_setting" "appgw" {
  name                       = "${var.environment}-${var.project_name}-appgw-diag"
  target_resource_id         = azurerm_application_gateway.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  # Logs
  enabled_log {
    category = "ApplicationGatewayAccessLog"
  }

  enabled_log {
    category = "ApplicationGatewayPerformanceLog"
  }

  enabled_log {
    category = "ApplicationGatewayFirewallLog"
  }

  # Metrics
  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# Network Security Group for Application Gateway Subnet
resource "azurerm_network_security_group" "appgw" {
  name                = "${var.environment}-${var.project_name}-appgw-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name

  # Allow Internet traffic to Application Gateway
  security_rule {
    name                       = "Allow-Internet-Inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["80", "443"]
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  # Allow GatewayManager (required for Application Gateway)
  security_rule {
    name                       = "Allow-GatewayManager"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "65200-65535"
    source_address_prefix      = "GatewayManager"
    destination_address_prefix = "*"
  }

  # Allow AzureLoadBalancer
  security_rule {
    name                       = "Allow-AzureLoadBalancer"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }

  tags = merge(
    var.tags,
    {
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  )
}

# Associate NSG with Application Gateway Subnet
resource "azurerm_subnet_network_security_group_association" "appgw" {
  subnet_id                 = var.subnet_id
  network_security_group_id = azurerm_network_security_group.appgw.id
}
