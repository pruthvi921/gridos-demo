# Terraform State Storage Bootstrap

This directory creates the Azure Storage Account used for storing Terraform remote state for all environments.

## Prerequisites

- Azure CLI installed and authenticated
- Terraform >= 1.5.0

## Initial Setup

**Run this ONCE before deploying any environment:**

```bash
cd terraform/bootstrap
terraform init
terraform plan
terraform apply
```

## Outputs

After applying, note the outputs:

```bash
terraform output -raw storage_account_name
terraform output -raw primary_access_key
```

## State File Location

This bootstrap configuration uses **local state** (`terraform.tfstate` in this directory). 

**Important:** 
- Commit the `.tfstate` file to version control OR
- Store it securely (Azure Storage, Terraform Cloud, etc.)
- This state file is critical for managing the remote state storage infrastructure

## Next Steps

After bootstrap is complete, deploy environments:

```bash
cd ../environments/dev
terraform init  # Will now use remote backend
terraform plan
terraform apply
```

## State Migration (Optional)

To migrate bootstrap state to the created storage account:

```bash
# Create backend.tf
cat > backend.tf << EOF
terraform {
  backend "azurerm" {
    resource_group_name  = "terraform-state-rg"
    storage_account_name = "gridostfstate"
    container_name       = "tfstate"
    key                  = "bootstrap.terraform.tfstate"
  }
}
EOF

# Migrate
terraform init -migrate-state
```

## Disaster Recovery

If storage account is lost:

1. Re-run bootstrap to recreate storage account
2. Import existing resources or recreate from scratch
3. Environment states will be lost unless backed up separately

**Best Practice:** Enable Azure Storage Account soft delete and versioning (already configured in module).
