output "id" {
  description = "ID of the Container Registry"
  value       = azurerm_container_registry.this.id
}

output "name" {
  description = "Name of the Container Registry"
  value       = azurerm_container_registry.this.name
}

output "login_server" {
  description = "Login server URL"
  value       = azurerm_container_registry.this.login_server
}

output "admin_username" {
  description = "Admin username (if admin enabled)"
  value       = var.admin_enabled ? azurerm_container_registry.this.admin_username : null
  sensitive   = true
}

output "admin_password" {
  description = "Admin password (if admin enabled)"
  value       = var.admin_enabled ? azurerm_container_registry.this.admin_password : null
  sensitive   = true
}
