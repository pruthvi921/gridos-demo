output "vnet_id" {
  description = "ID of the virtual network"
  value       = azurerm_virtual_network.main.id
}

output "vnet_name" {
  description = "Name of the virtual network"
  value       = azurerm_virtual_network.main.name
}

output "public_subnet_id" {
  description = "ID of the public subnet"
  value       = azurerm_subnet.public.id
}

output "aks_subnet_id" {
  description = "ID of the AKS subnet"
  value       = azurerm_subnet.private_aks.id
}

output "db_subnet_id" {
  description = "ID of the database subnet"
  value       = azurerm_subnet.private_db.id
}

output "appgw_subnet_id" {
  description = "ID of the Application Gateway subnet"
  value       = azurerm_subnet.appgw.id
}

output "private_dns_zone_id" {
  description = "ID of the private DNS zone for PostgreSQL"
  value       = azurerm_private_dns_zone.postgres.id
}

output "nat_gateway_id" {
  description = "ID of the NAT Gateway"
  value       = var.enable_nat_gateway ? azurerm_nat_gateway.main[0].id : null
}
