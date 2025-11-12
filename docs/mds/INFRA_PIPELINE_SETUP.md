# Infrastructure Pipeline Setup Guide

This guide explains how to set up and use the automated infrastructure deployment pipeline.

## 🏗️ Overview

The infrastructure pipeline automates:
1. **Terraform deployment** across dev/test/prod environments
2. **GitOps bootstrap** (Argo CD + Argo Rollouts installation)
3. **State management** via Azure Storage backend
4. **Approval gates** for test/prod deployments

## 📋 Prerequisites

### 1. Azure Service Principal

Create a Service Principal with Contributor access:

```bash
# Login to Azure
az login

# Create Service Principal
az ad sp create-for-rbac \
  --name "gridos-github-actions" \
  --role Contributor \
  --scopes /subscriptions/YOUR_SUBSCRIPTION_ID \
  --sdk-auth

# Save the JSON output - you'll need these values for GitHub Secrets
```

The output will look like:
```json
{
  "clientId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "clientSecret": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
  "subscriptionId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "tenantId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
}
```

### 2. Terraform State Storage

Create Azure Storage Account for Terraform state:

```bash
# Variables
RESOURCE_GROUP="terraform-state-rg"
STORAGE_ACCOUNT="gridostfstate$(date +%s)"  # Unique name
CONTAINER="tfstate"
LOCATION="norwayeast"

# Create resource group
az group create --name $RESOURCE_GROUP --location $LOCATION

# Create storage account
az storage account create \
  --name $STORAGE_ACCOUNT \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --sku Standard_LRS \
  --encryption-services blob

# Create container
az storage container create \
  --name $CONTAINER \
  --account-name $STORAGE_ACCOUNT

# Grant Service Principal access
SP_OBJECT_ID=$(az ad sp show --id YOUR_CLIENT_ID --query id -o tsv)
az role assignment create \
  --role "Storage Blob Data Contributor" \
  --assignee-object-id $SP_OBJECT_ID \
  --scope "/subscriptions/YOUR_SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Storage/storageAccounts/$STORAGE_ACCOUNT"

# Save these values for GitHub Secrets
echo "Resource Group: $RESOURCE_GROUP"
echo "Storage Account: $STORAGE_ACCOUNT"
```

## 🔐 GitHub Secrets Configuration

Go to your repository: **Settings → Secrets and variables → Actions → New repository secret**

Add the following secrets:

| Secret Name | Value | Description |
|------------|-------|-------------|
| `AZURE_CLIENT_ID` | `clientId` from SP output | Azure Service Principal Client ID |
| `AZURE_CLIENT_SECRET` | `clientSecret` from SP output | Azure Service Principal Secret |
| `AZURE_SUBSCRIPTION_ID` | `subscriptionId` from SP output | Azure Subscription ID |
| `AZURE_TENANT_ID` | `tenantId` from SP output | Azure Tenant ID |
| `TF_STATE_RESOURCE_GROUP` | Resource group name | Terraform state storage RG |
| `TF_STATE_STORAGE_ACCOUNT` | Storage account name | Terraform state storage account |

## 🌍 GitHub Environments Setup

Create environments for approval gates:

1. Go to **Settings → Environments**
2. Create the following environments:

### Dev Environment
- Name: `dev`
- No protection rules needed (auto-deploys)

### Test Environment
- Name: `test`
- Protection rules:
  - ✅ Required reviewers: Add yourself or team
  - ⏱️ Wait timer: 0 minutes (optional)

### Test Approval Environment
- Name: `test-approval`
- Protection rules:
  - ✅ Required reviewers: Add yourself or team

### Prod Environment
- Name: `prod`
- Protection rules:
  - ✅ Required reviewers: Add 2+ senior engineers
  - ⏱️ Wait timer: 5 minutes (recommended)

### Prod Approval Environment
- Name: `prod-approval`
- Protection rules:
  - ✅ Required reviewers: Add 2+ senior engineers

### Prod Destroy Environment
- Name: `prod-destroy`
- Protection rules:
  - ✅ Required reviewers: Add senior engineers + architect
  - ⏱️ Wait timer: 30 minutes

## 🚀 Usage

### Automatic Deployment (Push to Main)

When you push Terraform changes to `main` branch:
```bash
git add terraform/
git commit -m "Update infrastructure configuration"
git push origin main
```

**Result:**
- ✅ Automatically deploys to **dev** environment
- ✅ Runs bootstrap if Argo CD doesn't exist
- ⏸️ Does NOT deploy to test/prod (manual only)

### Manual Deployment

Go to **Actions → Infrastructure Deployment → Run workflow**

#### Deploy to Dev
1. Select:
   - Environment: `dev`
   - Action: `apply`
   - Auto-approve: ✅ (optional)
2. Click **Run workflow**
3. Deploys immediately (no approval needed)

#### Deploy to Test
1. Select:
   - Environment: `test`
   - Action: `apply`
   - Auto-approve: ❌ (requires approval)
2. Click **Run workflow**
3. **Pipeline pauses** for approval
4. Reviewer approves in **test-approval** environment
5. Deployment proceeds

#### Deploy to Production
1. Select:
   - Environment: `prod`
   - Action: `apply`
   - Auto-approve: ❌ (requires approval)
2. Click **Run workflow**
3. **Pipeline pauses** for approval
4. **Multiple reviewers** approve in **prod-approval**
5. Deployment proceeds (max-parallel: 1)

#### Plan Only
1. Select:
   - Environment: any
   - Action: `plan`
2. Click **Run workflow**
3. View plan output in job logs
4. No changes applied

#### Destroy Infrastructure
1. Select:
   - Environment: any
   - Action: `destroy`
   - Auto-approve: ❌ (ALWAYS requires approval)
2. Click **Run workflow**
3. **Pipeline pauses** at `{env}-destroy` environment
4. Reviewer approves
5. Destruction proceeds

⚠️ **WARNING:** Destroy is irreversible! Always review carefully.

## 📊 Pipeline Flow

### Automatic Flow (Push to Main)
```
Push to main (terraform/ changes)
    ↓
Determine Environments → [dev]
    ↓
Terraform Plan (dev)
    ↓
Terraform Apply (dev) - Auto-approved
    ↓
Bootstrap GitOps (if needed)
    ↓
Complete ✅
```

### Manual Flow - Test/Prod
```
Manual trigger (test/prod)
    ↓
Determine Environments → [test] or [prod]
    ↓
Terraform Plan
    ↓
Manual Approval Gate ⏸️
    ↓ (reviewer approves)
Terraform Apply
    ↓
Bootstrap GitOps (if needed)
    ↓
Complete ✅
```

## 🔍 Monitoring Deployments

### View Pipeline Status
1. Go to **Actions** tab
2. Click on running workflow
3. View real-time logs for each job

### View Terraform Plan
- Plans are saved as artifacts
- Download from workflow run page
- Valid for 5 days

### View Terraform State
State is stored in Azure Storage:
```bash
# Download state file
az storage blob download \
  --account-name $TF_STATE_STORAGE_ACCOUNT \
  --container-name tfstate \
  --name dev.terraform.tfstate \
  --file dev.tfstate
```

## 📝 Pipeline Features

### ✅ Safety Features
- **Plan before apply** - Always see changes first
- **Approval gates** - Test/prod require manual approval
- **State locking** - Prevents concurrent modifications
- **Max-parallel: 1** - One environment at a time
- **Artifact retention** - Plans saved for 5 days

### ✅ Automation Features
- **Auto-deploy dev** - On push to main
- **GitOps bootstrap** - Automatic Argo CD installation
- **PR comments** - Plan output in pull requests
- **Job summaries** - Clear deployment status

### ✅ Flexibility
- **Manual triggers** - Deploy any environment on demand
- **Plan-only mode** - Review changes without applying
- **Auto-approve option** - For CI/CD pipelines (use carefully)
- **Multi-environment** - Deploy to multiple envs in sequence

## 🛠️ Troubleshooting

### Pipeline Fails at "Terraform Init"
**Issue:** Backend configuration invalid

**Fix:**
```bash
# Verify secrets are set correctly
# Check storage account exists and SP has access
az storage account show --name $TF_STATE_STORAGE_ACCOUNT
```

### Pipeline Fails at "Terraform Apply"
**Issue:** Azure resources already exist or permission denied

**Fix:**
```bash
# Check Terraform state
# Verify Service Principal has Contributor role
az role assignment list --assignee YOUR_CLIENT_ID
```

### Bootstrap Fails - Argo CD Already Exists
**Expected:** Bootstrap step is skipped if Argo CD namespace exists

**Check:**
```bash
kubectl get namespace argocd
```

### Manual Approval Not Appearing
**Issue:** GitHub environment not configured

**Fix:**
1. Go to Settings → Environments
2. Create environment matching pipeline name
3. Add protection rules with required reviewers

## 🎯 Best Practices

### 1. Always Plan First
```yaml
# Run plan-only workflow first
Action: plan
```
Review output before running apply.

### 2. Dev → Test → Prod Progression
- Test changes in dev first
- Promote to test after validation
- Production last with full approvals

### 3. Protect Production
- Require 2+ approvers for prod
- Add wait timer (5-30 minutes)
- Review Terraform plan carefully

### 4. Use Auto-Approve Sparingly
- Only for dev environment
- Only for trusted changes
- Never for production

### 5. Monitor State Files
- Backup state regularly
- Enable versioning on storage account
- Review state changes

## 📚 Related Documentation

- [Complete Deployment Guide](../COMPLETE_DEPLOYMENT_GUIDE.md) - Full deployment walkthrough
- [GitOps Best Practices](../GITOPS_BEST_PRACTICES.md) - GitOps patterns and bootstrap
- [Quick Reference](../QUICK_REFERENCE.md) - Daily operations

## 🆘 Support

If you encounter issues:
1. Check pipeline logs in GitHub Actions
2. Review Terraform state in Azure Storage
3. Verify all secrets are configured correctly
4. Check Service Principal permissions

For GE Grid Solutions interview, be prepared to explain:
- Why we separate infrastructure and application deployments
- How approval gates protect production
- Why state is stored remotely
- How GitOps bootstrap works after infrastructure deployment
