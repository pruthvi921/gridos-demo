output "id" {
  description = "ID of the storage account"
  value       = azurerm_storage_account.this.id
}

output "name" {
  description = "Name of the storage account"
  value       = azurerm_storage_account.this.name
}

output "primary_blob_endpoint" {
  description = "Primary blob endpoint"
  value       = azurerm_storage_account.this.primary_blob_endpoint
}

output "primary_access_key" {
  description = "Primary access key"
  value       = azurerm_storage_account.this.primary_access_key
  sensitive   = true
}

output "secondary_access_key" {
  description = "Secondary access key"
  value       = azurerm_storage_account.this.secondary_access_key
  sensitive   = true
}

output "tfstate_container_name" {
  description = "Name of the tfstate container (if created)"
  value       = var.create_tfstate_container ? azurerm_storage_container.tfstate[0].name : null
}
