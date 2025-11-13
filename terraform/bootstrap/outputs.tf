output "resource_group_name" {
  description = "Name of the Terraform state resource group"
  value       = azurerm_resource_group.tfstate.name
}

output "storage_account_name" {
  description = "Name of the Terraform state storage account"
  value       = module.tfstate_storage.name
}

output "container_name" {
  description = "Name of the tfstate container"
  value       = module.tfstate_storage.tfstate_container_name
}

output "primary_access_key" {
  description = "Primary access key for the storage account"
  value       = module.tfstate_storage.primary_access_key
  sensitive   = true
}
