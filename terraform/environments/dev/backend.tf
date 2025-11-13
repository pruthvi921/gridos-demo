# Backend Configuration for Development Environment
# Remote state storage in Azure Storage Account

terraform {
  backend "azurerm" {
    resource_group_name  = "terraform-state-rg"
    storage_account_name = "gridostfstate"
    container_name       = "tfstate"
    key                  = "dev.terraform.tfstate"
  }
}
