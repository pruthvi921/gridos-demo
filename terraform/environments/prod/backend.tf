# Backend Configuration for Production Environment
# Remote state storage in Azure Storage Account
# Values are passed via GitHub Actions pipeline for security

terraform {
  backend "azurerm" {
    # These values are passed via -backend-config in the pipeline:
    # - resource_group_name  (from TF_STATE_RESOURCE_GROUP secret)
    # - storage_account_name (from TF_STATE_STORAGE_ACCOUNT secret)
    # - container_name       (default: "tfstate")
    # - key                  (environment-specific: "prod.terraform.tfstate")
  }
}
