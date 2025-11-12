# Infrastructure Testing Guide

Comprehensive testing for Terraform infrastructure to ensure quality, security, and compliance before deployment.

## 🧪 Test Types

### 1. **Static Analysis Tests**

#### Terraform Format Check
**What:** Ensures consistent code formatting across all Terraform files.

**Why:** Consistent formatting improves readability and reduces git conflicts.

**Command:**
```bash
terraform fmt -check -recursive terraform/
```

**Auto-fix:**
```bash
terraform fmt -recursive terraform/
```

#### TFLint
**What:** Static analysis for Terraform code to catch errors and enforce best practices.

**Why:** Identifies potential issues before deployment (deprecated resources, invalid configurations, etc.)

**Command:**
```bash
# Install TFLint
curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash

# Run TFLint
cd terraform/environments/dev
tflint --init
tflint
```

**What it checks:**
- Deprecated resource usage
- Invalid configurations
- Azure-specific best practices
- Resource naming conventions
- Missing required tags

### 2. **Security & Compliance Tests**

#### Checkov
**What:** Security and compliance scanner for Terraform.

**Why:** Identifies security misconfigurations before they reach production.

**Command:**
```bash
# Install Checkov
pip install checkov

# Run scan
checkov -d terraform/ --framework terraform
```

**What it checks:**
- Security group rules (overly permissive)
- Encryption settings (data at rest/transit)
- Public exposure risks
- IAM policies (least privilege)
- Logging and monitoring
- Compliance standards (CIS, PCI-DSS, HIPAA, etc.)

**Example findings:**
- ✅ Pass: Storage account has HTTPS only enabled
- ❌ Fail: AKS cluster allows HTTP traffic
- ⚠️ Warning: No backup policy configured

### 3. **Validation Tests**

#### Terraform Validate
**What:** Validates Terraform configuration syntax.

**Why:** Catches syntax errors and invalid references.

**Command:**
```bash
cd terraform/environments/dev
terraform init -backend=false
terraform validate
```

**What it checks:**
- HCL syntax correctness
- Resource attribute validity
- Variable references
- Module references
- Provider configuration

### 4. **Plan Tests**

#### Terraform Plan Dry Run
**What:** Generates an execution plan without accessing remote state.

**Why:** Verifies configurations can be planned successfully.

**Command:**
```bash
cd terraform/environments/dev
terraform init -backend=false
terraform plan -var-file=dev.tfvars
```

**What it shows:**
- Resources to be created/updated/destroyed
- Configuration errors
- Variable interpolation issues

### 5. **Cost Estimation**

#### Infracost (Optional)
**What:** Estimates cloud costs for Terraform changes.

**Why:** Prevents unexpected cost increases.

**Command:**
```bash
# Install Infracost
brew install infracost  # macOS
# or: curl -fsSL https://raw.githubusercontent.com/infracost/infracost/master/scripts/install.sh | sh

# Setup API key
infracost auth login

# Generate cost estimate
cd terraform/environments/dev
terraform init -backend=false
terraform plan -out=tfplan.binary
terraform show -json tfplan.binary > plan.json
infracost breakdown --path=plan.json
```

**Output example:**
```
 Name                                                   Monthly Qty  Unit         Monthly Cost 
                                                                                                
 azurerm_kubernetes_cluster.main                                                               
 ├─ Instance usage (pay as you go, Standard_D4s_v3)            730  hours              $175.20 
 ├─ Managed Disk (Premium SSD, LRS, P10)                          1  months              $19.71 
 └─ Load balancer                                                 1  months               $0.00 
                                                                                                
 azurerm_application_gateway.main                                                              
 ├─ Application gateway usage                                   730  hours              $175.20 
 ├─ Data processed                                           10,000  GB                  $80.00 
                                                                                                
 OVERALL TOTAL                                                                           $450.11 
```

### 6. **Documentation Tests**

#### README Check
**What:** Ensures all modules have documentation.

**Why:** Improves maintainability and onboarding.

**Command:**
```bash
# Check for missing README files
for module in terraform/modules/*; do
  if [ ! -f "$module/README.md" ]; then
    echo "Missing: $module/README.md"
  fi
done
```

### 7. **Secret Scanning**

#### Hardcoded Secret Check
**What:** Scans for hardcoded secrets in code.

**Why:** Prevents credential leaks.

**Command:**
```bash
# Check for common secret patterns
grep -r -E "(password|secret|key)\s*=\s*\"[^\"]+\"" terraform/environments/
```

---

## 🚀 Running Tests

### Locally (Before Commit)

```bash
# 1. Format check and auto-fix
terraform fmt -recursive terraform/

# 2. Run validation
cd terraform/environments/dev
terraform init -backend=false
terraform validate

# 3. Run TFLint
tflint --init
tflint

# 4. Run Checkov security scan
checkov -d terraform/ --framework terraform --compact

# 5. Test plan
terraform plan -var-file=dev.tfvars
```

### In CI/CD Pipeline

Tests run automatically on:
- **Pull Requests** - All tests run, results posted as PR comment
- **Push to main** - Tests run before deployment
- **Manual trigger** - Can run tests independently

**Workflow:** `.github/workflows/infra-test.yml`

**View results:**
1. Go to **Actions** tab
2. Click on **Infrastructure Tests** workflow
3. Review each test job

---

## 📊 Test Results Interpretation

### ✅ All Tests Pass
```
✅ Terraform Format - Pass
✅ TFLint - Pass
✅ Checkov Security - Pass
✅ Terraform Validate - Pass
✅ Terraform Plan - Pass
✅ Documentation - Pass
✅ Variable Validation - Pass
```

**Action:** Safe to proceed with deployment!

### ⚠️ Some Tests Warn
```
✅ Terraform Format - Pass
✅ TFLint - Pass
⚠️ Checkov Security - 3 warnings (low severity)
✅ Terraform Validate - Pass
✅ Terraform Plan - Pass
```

**Action:** Review warnings, determine if acceptable, document exceptions.

### ❌ Tests Fail
```
✅ Terraform Format - Pass
❌ TFLint - 2 errors
❌ Checkov Security - 5 failures
✅ Terraform Validate - Pass
❌ Terraform Plan - Fail
```

**Action:** Fix errors before deployment. Deployment pipeline will be blocked.

---

## 🔧 Fixing Common Issues

### Format Issues
```bash
# Auto-fix formatting
terraform fmt -recursive terraform/
git add terraform/
git commit -m "Fix: terraform formatting"
```

### TFLint Errors

**Error:** Deprecated resource
```
Error: azurerm_virtual_machine is deprecated, use azurerm_linux_virtual_machine instead
```

**Fix:** Update to newer resource type per TFLint suggestion.

**Error:** Missing required tags
```
Error: Resource is missing required tags: Environment, Project
```

**Fix:** Add tags to resource:
```hcl
tags = {
  Environment = var.environment
  Project     = var.project_name
  ManagedBy   = "Terraform"
}
```

### Checkov Security Issues

**Error:** CKV_AZURE_4: Storage account not using HTTPS only
```hcl
resource "azurerm_storage_account" "example" {
  enable_https_traffic_only = true  # Add this
}
```

**Error:** CKV_AZURE_7: AKS cluster has no network policy
```hcl
resource "azurerm_kubernetes_cluster" "main" {
  network_profile {
    network_policy = "azure"  # or "calico"
  }
}
```

**Error:** CKV_AZURE_117: Disk encryption not enabled
```hcl
resource "azurerm_managed_disk" "example" {
  encryption_settings {
    enabled = true
  }
}
```

### Validation Errors

**Error:** Invalid resource reference
```
Error: Reference to undeclared resource
```

**Fix:** Ensure resource exists or fix typo in reference.

**Error:** Invalid variable type
```
Error: Incorrect variable type; expected string, got number
```

**Fix:** Update variable type or convert value.

---

## 🎯 Test Coverage Goals

### Critical (Must Pass for Deployment)
- ✅ Terraform Format
- ✅ Terraform Validate
- ✅ TFLint
- ✅ Variable Validation

### Important (Should Pass, Can Override with Justification)
- ⚠️ Checkov Security (medium/high severity)
- ⚠️ Documentation Check

### Nice to Have (Informational)
- 💰 Cost Estimation
- 📊 Compliance Reports

---

## 🔄 Pre-Commit Hooks (Optional)

Set up automatic testing before commits:

```bash
# Install pre-commit
pip install pre-commit

# Create .pre-commit-config.yaml
cat > .pre-commit-config.yaml << 'EOF'
repos:
  - repo: https://github.com/antonbabenko/pre-commit-terraform
    rev: v1.86.0
    hooks:
      - id: terraform_fmt
      - id: terraform_validate
      - id: terraform_tflint
      - id: terraform_checkov
EOF

# Install hooks
pre-commit install

# Now tests run automatically on git commit
```

---

## 📈 Continuous Improvement

### Adding New Tests

1. **Add test to workflow:**
   ```yaml
   new-test:
     name: New Test Name
     runs-on: ubuntu-latest
     steps:
       - name: Run new test
         run: ./test-script.sh
   ```

2. **Add to test summary:**
   ```yaml
   needs: 
     - existing-test
     - new-test  # Add here
   ```

### Custom Compliance Policies

Create custom Checkov policies:

```python
# custom_checks/check_custom_policy.py
from checkov.terraform.checks.resource.base_resource_check import BaseResourceCheck

class CustomCheck(BaseResourceCheck):
    def __init__(self):
        name = "Ensure custom requirement"
        id = "CKV_CUSTOM_1"
        supported_resources = ['azurerm_kubernetes_cluster']
        categories = ['CUSTOM']
        super().__init__(name=name, id=id, categories=categories, 
                        supported_resources=supported_resources)

    def scan_resource_conf(self, conf):
        # Your check logic here
        return CheckResult.PASSED
```

Run with:
```bash
checkov -d terraform/ --external-checks-dir ./custom_checks/
```

---

## 🎓 Interview Talking Points

> **"We have comprehensive infrastructure testing with multiple layers:**
> 
> **1. Static Analysis** - TFLint catches errors and enforces best practices before code even runs.
> 
> **2. Security Scanning** - Checkov scans for 1000+ security checks across CIS benchmarks, ensuring our infrastructure is secure by default.
> 
> **3. Validation** - Terraform validate and plan tests ensure configurations are syntactically correct and logically sound.
> 
> **4. Cost Awareness** - Infracost gives us visibility into cost implications before deployment, preventing budget surprises.
> 
> **5. Automated in CI/CD** - All tests run automatically on PRs and before deployment. Failed tests block deployment.
> 
> **6. Fast Feedback** - Tests run in parallel, complete in ~5-7 minutes, giving developers rapid feedback.
> 
> This shift-left testing approach catches issues early when they're cheap to fix, rather than in production where they're expensive."

---

## 📚 Related Documentation

- [Infrastructure Pipeline Setup](INFRA_PIPELINE_SETUP.md) - Deployment automation
- [Complete Deployment Guide](../COMPLETE_DEPLOYMENT_GUIDE.md) - Full deployment process
- [GitOps Best Practices](../GITOPS_BEST_PRACTICES.md) - GitOps patterns

## 🔗 External Resources

- [TFLint Documentation](https://github.com/terraform-linters/tflint)
- [Checkov Documentation](https://www.checkov.io/)
- [Terraform Testing Guide](https://www.terraform.io/docs/language/modules/testing-experiment.html)
- [Infracost Documentation](https://www.infracost.io/docs/)
