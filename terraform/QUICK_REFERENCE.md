# Quick Terraform Reference

## Deployment Commands

### Development Environment
```bash
cd terraform/environments/dev
terraform init
terraform validate
terraform plan -var-file=dev.tfvars
terraform apply -var-file=dev.tfvars
```

### Test Environment
```bash
cd terraform/environments/test
terraform init
terraform validate
terraform plan -var-file=test.tfvars
terraform apply -var-file=test.tfvars
```

### Production Environment
```bash
cd terraform/environments/prod
terraform init
terraform validate
terraform plan -var-file=prod.tfvars
terraform apply -var-file=prod.tfvars
```

## Variable Precedence
1. Default values in variables.tf
2. *.tfvars files (via -var-file)
3. Command line -var flags

## Environment Comparison

| Feature | Dev | Test | Prod |
|---------|-----|------|------|
| Database | B_Standard_B2s (32GB) | GP_Standard_D2s_v3 (64GB) | GP_Standard_D4s_v3 (128GB) |
| DB HA | ❌ | ❌ | ✅ |
| AKS Nodes | 1-2 (max 4) | 2-3 (max 6) | 3-5 (max 20) |
| Node Size | Standard_B4ms | Standard_D4s_v3 | Standard_D8s_v3 |
| Monitoring Pool | ❌ | ✅ | ✅ |
| Log Retention | 30 days | 60 days | 90 days |
| Backups | 7 days | 14 days | 35 days |
| ACR SKU | Standard | Standard | Premium |
| Purge Protection | ❌ | ❌ | ✅ |
