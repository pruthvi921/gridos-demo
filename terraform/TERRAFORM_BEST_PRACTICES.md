# Terraform Best Practices - Directory Structure Guide

This document explains the Terraform directory structure and best practices used in this project.

## Directory Structure

```
terraform/
├── modules/                      # Reusable Terraform modules
│   ├── networking/              # Network infrastructure module
│   │   ├── main.tf              # Resource definitions
│   │   ├── variables.tf         # Input variables
│   │   └── outputs.tf           # Output values
│   ├── kubernetes/              # AKS cluster module
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── database/                # PostgreSQL module
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
└── environments/                # Environment-specific configurations
    ├── dev/                     # Development environment
    │   ├── main.tf              # Environment composition
    │   ├── variables.tf         # Environment variables with defaults
    │   ├── outputs.tf           # Environment outputs
    │   └── dev.tfvars           # Dev-specific values
    ├── test/                    # Test environment
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   └── test.tfvars          # Test-specific values
    └── prod/                    # Production environment
        ├── main.tf
        ├── variables.tf
        ├── outputs.tf
        └── prod.tfvars          # Prod-specific values
```

## Best Practices Implemented

### 1. Module-Based Architecture
- **Separation of Concerns**: Each module handles a specific infrastructure component
- **Reusability**: Modules can be used across multiple environments
- **Testability**: Modules can be tested independently
- **Maintainability**: Changes to a module affect all environments consistently

### 2. Environment Separation
- **Isolated State**: Each environment has its own state file
- **Different Configurations**: Each environment can have different sizing/features
- **Safe Changes**: Changes to dev don't affect test or prod

### 3. Variable Management

#### variables.tf
Contains variable **definitions** with:
- Type constraints
- Descriptions
- Default values (where appropriate)
- Validation rules

```hcl
variable "postgres_sku_name" {
  description = "SKU name for PostgreSQL server"
  type        = string
  default     = "GP_Standard_D4s_v3"
}
```

#### *.tfvars Files
Contains actual **values** for each environment:
- `dev.tfvars` - Development values (small, cost-optimized)
- `test.tfvars` - Test values (medium, balanced)
- `prod.tfvars` - Production values (large, performance-optimized)

**Never commit sensitive values to .tfvars files!**

### 4. Usage Patterns

#### Deploy to Development
```bash
cd terraform/environments/dev
terraform init
terraform plan -var-file=dev.tfvars
terraform apply -var-file=dev.tfvars
```

#### Deploy to Production
```bash
cd terraform/environments/prod
terraform init
terraform plan -var-file=prod.tfvars
terraform apply -var-file=prod.tfvars
```

### 5. Variable Precedence
Terraform loads variables in this order (later overrides earlier):
1. Default values in `variables.tf`
2. Environment variables `TF_VAR_*`
3. `terraform.tfvars` (if present)
4. `*.auto.tfvars` (alphabetically)
5. `-var-file` flag
6. `-var` flag

**Our approach**: Use `-var-file` flag with environment-specific files.

### 6. State Management

Each environment should have its own state file:

```hcl
backend "azurerm" {
  resource_group_name  = "gridos-terraform-state-rg"
  storage_account_name = "gridostfstatedev"
  container_name       = "tfstate"
  key                  = "dev.terraform.tfstate"  # Different per environment
}
```

### 7. Environment-Specific Sizing

| Resource | Dev | Test | Prod |
|----------|-----|------|------|
| DB SKU | B_Standard_B2s | GP_Standard_D2s_v3 | GP_Standard_D4s_v3 |
| DB Storage | 32 GB | 64 GB | 128 GB |
| DB HA | No | No | Yes |
| AKS System Nodes | 1 | 2 | 3 |
| AKS User Nodes | 2-4 | 3-6 | 5-20 |
| Log Retention | 30 days | 60 days | 90 days |
| ACR SKU | Standard | Standard | Premium |

### 8. Tagging Strategy

Common tags defined in main.tf:
```hcl
locals {
  common_tags = merge(
    {
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "Terraform"
      CostCenter  = var.cost_center
      Owner       = var.owner
    },
    var.additional_tags
  )
}
```

Environment-specific tags in .tfvars:
```hcl
additional_tags = {
  AutoShutdown = "enabled"    # Dev/Test only
  CriticalSystem = "true"     # Prod only
  SLA = "99.9"               # Prod only
}
```

## Common Terraform Commands

### Initialize
```bash
terraform init
```

### Validate Syntax
```bash
terraform validate
```

### Format Code
```bash
terraform fmt -recursive
```

### Plan Changes
```bash
terraform plan -var-file=dev.tfvars -out=tfplan
```

### Apply Changes
```bash
terraform apply tfplan
```

### Destroy Resources
```bash
terraform destroy -var-file=dev.tfvars
```

### View State
```bash
terraform show
terraform state list
```

### Import Existing Resources
```bash
terraform import module.networking.azurerm_resource_group.main /subscriptions/.../resourceGroups/...
```

## Security Best Practices

### 1. Secrets Management
- ❌ Never commit `.tfvars` files with secrets to Git
- ✅ Use Azure Key Vault for sensitive data
- ✅ Use service principals or managed identities
- ✅ Store state files in encrypted backend

### 2. Access Control
- Use Azure AD authentication for Terraform
- Implement least-privilege access policies
- Use separate service principals per environment

### 3. State File Protection
```hcl
backend "azurerm" {
  # Enable encryption at rest
  # Use separate storage account per environment
  # Enable soft delete and versioning
  # Implement state locking
}
```

## CI/CD Integration

### GitHub Actions Example
```yaml
- name: Terraform Apply
  run: |
    cd terraform/environments/${{ matrix.environment }}
    terraform init
    terraform validate
    terraform plan -var-file=${{ matrix.environment }}.tfvars -out=tfplan
    terraform apply tfplan
  env:
    ARM_CLIENT_ID: ${{ secrets.ARM_CLIENT_ID }}
    ARM_CLIENT_SECRET: ${{ secrets.ARM_CLIENT_SECRET }}
    ARM_SUBSCRIPTION_ID: ${{ secrets.ARM_SUBSCRIPTION_ID }}
    ARM_TENANT_ID: ${{ secrets.ARM_TENANT_ID }}
```

## Module Development Guidelines

### Module Requirements
1. **README.md**: Document inputs, outputs, and usage
2. **variables.tf**: Define all inputs with descriptions
3. **outputs.tf**: Expose necessary values
4. **examples/**: Provide usage examples
5. **Versioning**: Use semantic versioning for modules

### Module Best Practices
- Keep modules focused (single responsibility)
- Use consistent naming conventions
- Provide sensible defaults
- Add validation rules
- Document breaking changes

## Troubleshooting

### State Lock Issues
```bash
terraform force-unlock <LOCK_ID>
```

### State Drift
```bash
terraform refresh
terraform plan
```

### Import Existing Resources
```bash
terraform import <resource_type>.<name> <azure_resource_id>
```

## Additional Resources

- [Terraform Azure Provider Documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)
- [Azure Well-Architected Framework](https://learn.microsoft.com/azure/well-architected/)
- [Terraform Style Guide](https://developer.hashicorp.com/terraform/language/style)
