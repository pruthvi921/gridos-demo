# Terraform State Storage Bootstrap
# This creates the Azure Storage Account for storing Terraform remote state
# Run this ONCE before deploying environments

locals {
  common_tags = {
    Purpose    = "Terraform Remote State"
    ManagedBy  = "Terraform Bootstrap"
    Project    = "GridOS"
  }
}

# Resource Group for Terraform State
resource "azurerm_resource_group" "tfstate" {
  name     = "terraform-state-rg"
  location = var.location
  tags     = local.common_tags
}

# Storage Account Module for Terraform State
module "tfstate_storage" {
  source = "../modules/storage"

  name                = "gridostfstate"
  resource_group_name = azurerm_resource_group.tfstate.name
  location            = azurerm_resource_group.tfstate.location
  account_tier        = "Standard"
  replication_type    = "GRS"  # Geo-redundant for state protection

  # Security settings
  allow_public_access        = false
  shared_access_key_enabled  = true  # Required for Terraform backend
  enable_versioning          = true  # Version state files
  enable_soft_delete         = true
  soft_delete_retention_days = 30

  # Create tfstate container
  create_tfstate_container = true

  tags = local.common_tags
}
