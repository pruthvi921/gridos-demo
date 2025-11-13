# Application Gateway Module Outputs

output "id" {
  description = "Application Gateway resource ID"
  value       = azurerm_application_gateway.main.id
}

output "name" {
  description = "Application Gateway name"
  value       = azurerm_application_gateway.main.name
}

output "public_ip_address" {
  description = "Application Gateway public IP address"
  value       = azurerm_public_ip.appgw.ip_address
}

output "public_ip_fqdn" {
  description = "Application Gateway public IP FQDN"
  value       = azurerm_public_ip.appgw.fqdn
}

output "backend_address_pool_ids" {
  description = "Backend address pool IDs"
  value       = azurerm_application_gateway.main.backend_address_pool[*].id
}

output "identity_principal_id" {
  description = "Principal ID of the managed identity"
  value       = var.identity_ids == null ? azurerm_user_assigned_identity.appgw[0].principal_id : null
}

output "identity_client_id" {
  description = "Client ID of the managed identity"
  value       = var.identity_ids == null ? azurerm_user_assigned_identity.appgw[0].client_id : null
}

output "identity_id" {
  description = "ID of the managed identity"
  value       = var.identity_ids == null ? azurerm_user_assigned_identity.appgw[0].id : null
}
