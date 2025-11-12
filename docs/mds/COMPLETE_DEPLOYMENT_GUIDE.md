# Complete Deployment Guide - Zero to Production

This guide will take you from nothing to a fully deployed GitOps infrastructure using a **two-stage approach**: Terraform for infrastructure, then a one-time bootstrap for GitOps tools.

## 🎯 What You'll Deploy

### Stage 1: Infrastructure (Terraform)
```
Terraform
    ↓
┌─────────────────────────────────────────┐
│ Azure Infrastructure                     │
│  - AKS Cluster (3 nodes)                │
│  - Application Gateway + AGIC           │
│  - Azure Container Registry             │
│  - Virtual Network + Subnets            │
│  - Log Analytics Workspace              │
│  - Application Insights                 │
└─────────────────────────────────────────┘
```

### Stage 2: GitOps Bootstrap (One-Time Script)
```
scripts/install-argocd.sh
    ↓
┌─────────────────────────────────────────┐
│ GitOps Tools (via Helm)                 │
│  - Argo CD (HA mode, 2 replicas)       │
│  - Argo Rollouts Controller             │
│  - Application CRDs (dev/test/prod)     │
└─────────────────────────────────────────┘
    ↓
┌─────────────────────────────────────────┐
│ Applications (via GitOps)                │
│  - GridOS App deployed from Git         │
│  - Canary deployment strategy           │
│  - Prometheus-based analysis            │
└─────────────────────────────────────────┘
```

**Total deployment time: ~25-30 minutes**

---

## ⚙️ Prerequisites

### Required Tools

Install these before starting:

1. **Azure CLI** (az)
   ```bash
   # Windows (via winget)
   winget install Microsoft.AzureCLI
   
   # Or download from: https://aka.ms/installazurecliwindows
   ```

2. **Terraform** (>= 1.5.0)
   ```bash
   # Windows (via Chocolatey)
   choco install terraform
   
   # Or download from: https://www.terraform.io/downloads
   ```

3. **kubectl**
   ```bash
   # Install via Azure CLI
   az aks install-cli
   ```

4. **Helm** (>= 3.12.0)
   ```bash
   # Windows (via Chocolatey)
   choco install kubernetes-helm
   
   # Or download from: https://helm.sh/docs/intro/install/
   ```

5. **Git**
   ```bash
   # Windows
   winget install Git.Git
   ```

### Verify Installation

```bash
az --version          # Should be >= 2.50.0
terraform --version   # Should be >= 1.5.0
kubectl version --client
helm version
git --version
```

---

## 🔐 GitHub Setup

### 1. Create Personal Access Token (PAT)

1. Go to: https://github.com/settings/tokens/new
2. Settings:
   - **Note:** `GridOS GitOps Token`
   - **Expiration:** 90 days (or as needed)
   - **Scopes:**
     - ✅ `repo` (Full control of private repositories)
     - ✅ `workflow` (Update GitHub Action workflows)
     - ✅ `admin:repo_hook` (Full control of repository hooks)

3. Click **Generate token**
4. **SAVE THE TOKEN** - you won't see it again!

### 2. Fork or Clone Repository

```bash
# Clone your repository
git clone https://github.com/YOUR_ORG/sharedinfra.git
cd sharedinfra
```

### 3. Update GitOps Configuration

Edit `terraform/environments/dev/gitops.tfvars`:

```hcl
# GitHub Configuration
github_repo_url = "https://github.com/YOUR_ORG/sharedinfra"
github_org      = "YOUR_ORG"
github_repo     = "sharedinfra"

# Argo CD Domains (update these to your actual domains)
argocd_domain   = "argocd-dev.gridos.example.com"
rollouts_domain = "rollouts-dev.gridos.example.com"

# Leave these empty - will be set via environment variables for security
github_username = ""
github_token    = ""
```

---

## 🚀 Deployment

This is a **two-stage process**:
1. **Stage 1:** Terraform deploys Azure infrastructure (~20-25 min)
2. **Stage 2:** Bootstrap script installs GitOps tools (~5 min)

---

### Stage 1: Deploy Infrastructure with Terraform

#### Step 1: Azure Login

```bash
az login
az account set --subscription "YOUR_SUBSCRIPTION_NAME"
```

#### Step 2: Navigate to Dev Environment

```bash
cd terraform/environments/dev
```

#### Step 3: Initialize Terraform

```bash
terraform init
```

#### Step 4: Create and Review Plan

```bash
terraform plan -out=tfplan
```

Review the plan. You should see ~30 Azure resources:
- AKS cluster with 3 nodes
- Application Gateway (WAF_v2)
- Azure Container Registry (Premium)
- Virtual Network + Subnets
- Log Analytics + Application Insights
- IAM role assignments

#### Step 5: Apply Infrastructure

```bash
terraform apply tfplan
```

**Time: 20-25 minutes**

Terraform creates:
- ✅ Resource group
- ✅ Virtual network with subnets
- ✅ AKS cluster (System + User node pools)
- ✅ Application Gateway + AGIC
- ✅ Azure Container Registry
- ✅ Log Analytics Workspace
- ✅ Application Insights
- ✅ All IAM role assignments

#### Step 6: Get AKS Credentials

```bash
az aks get-credentials \
  --resource-group gridos-dev-rg \
  --name gridos-dev-aks \
  --overwrite-existing
```

#### Step 7: Verify Cluster

```bash
kubectl cluster-info
kubectl get nodes
```

You should see 3 nodes in Ready state.

---

### Stage 2: Bootstrap GitOps (One-Time Setup)

Now we install Argo CD - this is the **ONE exception** to "everything in Git" because we need Argo CD to read from Git in the first place (chicken-and-egg problem).

The bootstrap script is **tracked in Git** for reproducibility, but only needs to be **run once**.

#### Step 1: Return to Repo Root

```bash
cd ../../..  # Back to sharedinfra/
```

#### Step 2: Run Bootstrap Script

```bash
# Make executable (Linux/Mac)
chmod +x scripts/install-argocd.sh

# Run bootstrap
./scripts/install-argocd.sh
```

**Time: ~5 minutes**

The script will:
1. ✅ Check prerequisites (kubectl, helm, cluster connectivity)
2. ✅ Add Argo Helm repository
3. ✅ Install Argo CD (HA mode with values from `argocd/helm-values/argocd-values.yaml`)
4. ✅ Install Argo Rollouts
5. ✅ Wait for Argo CD to be ready
6. ✅ Create Applications (dev/test/prod) from `argocd/applications/`
7. ✅ Display initial admin password and access instructions

#### Step 3: Get Argo CD Password

The script displays it, but you can retrieve it anytime:

```bash
kubectl get secret argocd-initial-admin-secret \
  -n argocd \
  -o jsonpath="{.data.password}" | base64 --decode
echo  # Add newline
```

#### Step 4: Access Argo CD UI

**Option A: Port-forward (immediate access)**
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```
Then open: https://localhost:8080

**Option B: Ingress (requires DNS)**
- Update `argocd/helm-values/argocd-values.yaml` with your domain
- Create DNS A record pointing to Application Gateway IP
- Access: https://argocd.yourdomain.com

#### Step 5: Login and Change Password

```bash
# Login via CLI
argocd login localhost:8080

# Change admin password
argocd account update-password
```

#### Step 6: Verify Applications

```bash
# List all applications
kubectl get applications -n argocd

# Watch sync status
kubectl get applications -n argocd -w
```

You should see:
- `gridos-dev` - Auto-sync enabled (deploys immediately)
- `gridos-test` - Auto-sync enabled
- `gridos-prod` - Manual sync required

---

## 🎉 Deployment Complete!

**What just happened:**

1. ✅ **Infrastructure deployed** - Terraform created all Azure resources
2. ✅ **GitOps installed** - Argo CD and Argo Rollouts running in cluster
3. ✅ **Applications connected** - Argo CD watching this Git repository
4. ✅ **GitOps active** - Any Git commit will trigger automatic sync

**From now on, all changes happen via Git commits!**

---

## 🌐 DNS Configuration (Optional)

For production-grade ingress with custom domains:

#### Step 4: Create Terraform Plan

```bash
terraform plan \
  -var-file="dev.tfvars" \
  -var-file="gitops.tfvars" \
  -var="github_username=$GITHUB_USERNAME" \
  -var="github_token=$GITHUB_TOKEN" \
  -out=tfplan
```

Review the plan. You should see resources being created:
- ~30 Azure resources (AKS, App Gateway, ACR, etc.)
- Argo CD installation (via null_resource + helm)
- Argo CD Applications

#### Step 5: Apply Terraform

```bash
terraform apply tfplan
```

This will take **20-25 minutes**. Terraform will:
1. Create Azure infrastructure
2. Wait for AKS to be ready
3. Install Argo CD via Helm
4. Install Argo Rollouts
5. Configure GitHub integration
6. Deploy Argo CD Applications

#### Step 6: Get AKS Credentials

```bash
# Should already be done by Terraform, but if needed:
az aks get-credentials \
  --name $(terraform output -raw cluster_name) \
  --resource-group $(terraform output -raw resource_group_name) \
  --overwrite-existing
```

#### Step 7: Verify Deployment

```bash
# Check cluster connectivity
kubectl cluster-info

# Check Argo CD pods
kubectl get pods -n argocd

# Check Argo Rollouts pods
kubectl get pods -n argo-rollouts

# Check Applications
kubectl get applications -n argocd
```

---

## 🌐 DNS Configuration

After deployment, you need to configure DNS for Argo CD and Rollouts Dashboard.

### 1. Get Application Gateway Public IP

```bash
# From Terraform output
terraform output application_gateway_public_ip

# Or from Azure CLI
az network public-ip show \
  --name $(terraform output -raw resource_group_name)-appgw-pip \
  --resource-group $(terraform output -raw resource_group_name) \
  --query ipAddress -o tsv
```

### 2. Create DNS Records

In your DNS provider (e.g., Azure DNS, Cloudflare, GoDaddy):

```
Type: A
Name: argocd-dev.gridos.example.com
Value: <Application Gateway Public IP>
TTL: 300

Type: A
Name: rollouts-dev.gridos.example.com
Value: <Application Gateway Public IP>
TTL: 300
```

### 3. Verify DNS Resolution

```bash
nslookup argocd-dev.gridos.example.com
nslookup rollouts-dev.gridos.example.com
```

---

## 🔍 Access Your Deployment

### Argo CD UI

```bash
# Get URL
terraform output argocd_url

# Get admin password
cat argocd-password.txt
# Or retrieve from Kubernetes
kubectl get secret argocd-initial-admin-secret \
  -n argocd \
  -o jsonpath="{.data.password}" | base64 -d
```

**Access:**
- URL: https://argocd-dev.gridos.example.com
- Username: `admin`
- Password: (from argocd-password.txt)

### Argo Rollouts Dashboard

```bash
# Get URL
terraform output rollouts_dashboard_url
```

**Access:**
- URL: https://rollouts-dev.gridos.example.com
- No authentication required (consider adding auth for prod)

### Argo CD CLI (Optional)

```bash
# Install Argo CD CLI
# Windows (via Chocolatey)
choco install argocd-cli

# Login
argocd login argocd-dev.gridos.example.com \
  --username admin \
  --password $(cat argocd-password.txt)

# List applications
argocd app list

# Get application details
argocd app get gridos-dev

# Sync application manually
argocd app sync gridos-dev

# Watch sync progress
argocd app sync gridos-dev --watch
```

---

## ✅ Verify GitOps is Working

### 1. Check Argo CD Application Status

In Argo CD UI:
1. Look for `gridos-dev` application
2. Status should be **Synced** and **Healthy**
3. Click on the application to see resources

Or via CLI:
```bash
kubectl get applications -n argocd
argocd app get gridos-dev
```

### 2. Check Application Pods

```bash
# Check GridOS application
kubectl get pods -n gridos-dev

# Should see:
# - gridos-xxx (stable pods)
# - May see canary pods during rollout
```

### 3. Test GitOps Flow

Make a change and push to GitHub:

```bash
# Edit image tag in Kustomize
cd applications/gridos/overlays/dev

# Update kustomization.yaml
cat > kustomization.yaml <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: gridos-dev

resources:
  - ../../base

images:
  - name: gridosacr.azurecr.io/gridos-app
    newTag: v1.0.1  # Changed from v1.0.0

patches:
  - target:
      kind: Rollout
      name: gridos
    patch: |-
      - op: replace
        path: /spec/replicas
        value: 2
EOF

# Commit and push
git add .
git commit -m "Update to v1.0.1"
git push origin main
```

**Watch the magic happen:**

```bash
# Argo CD syncs within 3 minutes (default reconciliation)
argocd app get gridos-dev --watch

# Watch rollout progress
kubectl argo rollouts get rollout gridos -n gridos-dev --watch
```

You'll see:
1. Argo CD detects change (within 3 min)
2. Argo CD syncs new manifests
3. Argo Rollouts starts canary deployment:
   - 10% traffic to canary (30s)
   - Prometheus analysis
   - 25% traffic (30s)
   - Analysis
   - 50% traffic (30s)
   - Analysis
   - 100% traffic (full rollout)

**Total canary time: ~2 minutes**

---

## 🎯 What Just Happened?

Let's understand the complete flow:

### Infrastructure Layer (Terraform)

```
terraform apply
    ↓
Creates Azure Resources:
    - Resource Group
    - Virtual Network + Subnets
    - AKS Cluster (3 nodes, Standard_D4s_v3)
    - Application Gateway v2 (WAF_v2 SKU)
    - Azure Container Registry (Premium)
    - Log Analytics Workspace
    - Azure Key Vault
    - Application Insights
    ↓
Installs GitOps Tools (via Helm):
    - Argo CD (HA mode, 2 replicas)
    - Argo Rollouts (2 replicas)
    ↓
Configures Argo CD:
    - GitHub repository connection
    - Creates gridos-dev Application
    - Auto-sync enabled
```

### GitOps Layer (Argo CD)

```
Argo CD starts watching:
    GitHub repo: github.com/YOUR_ORG/sharedinfra
    Path: applications/gridos/overlays/dev
    ↓
Every 3 minutes (reconciliation):
    1. Fetch latest commit from GitHub
    2. Compare with cluster state
    3. If different → Sync (apply changes)
    ↓
Syncing means:
    kubectl apply -k applications/gridos/overlays/dev
    ↓
Kustomize generates final YAML:
    base/ (common config)
    + overlays/dev/ (dev-specific patches)
    = Final manifest applied to cluster
```

### Deployment Layer (Argo Rollouts)

```
New image deployed:
    ↓
Argo Rollouts detects change
    ↓
Starts Canary Strategy:
    
    Step 1: 10% traffic to canary
        - Deploy canary pods
        - Route 10% traffic via services
        - Run analysis (30s)
        - Check Prometheus metrics:
          * Success rate > 99%
          * Latency p95 < 500ms
          * Error rate < 1%
        ↓
    Step 2: 25% traffic to canary
        - Scale canary
        - Route 25% traffic
        - Run analysis (30s)
        ↓
    Step 3: 50% traffic to canary
        - Scale canary
        - Route 50% traffic
        - Run analysis (30s)
        ↓
    Step 4: 100% traffic (promotion)
        - Replace stable with canary
        - All traffic to new version
        ↓
    Success! 🎉
    
If analysis fails at any step:
    - Rollback to stable version
    - Alert via GitHub status
    - Keep stable version running
```

---

## 📊 Monitoring Your Deployment

### Argo CD Metrics

```bash
# Application health
kubectl get applications -n argocd

# Sync status
argocd app list

# Detailed application info
argocd app get gridos-dev
```

### Argo Rollouts Status

```bash
# Rollout status
kubectl argo rollouts get rollout gridos -n gridos-dev

# Watch rollout progress
kubectl argo rollouts get rollout gridos -n gridos-dev --watch

# Rollout history
kubectl argo rollouts history rollout gridos -n gridos-dev

# Analysis run status
kubectl get analysisruns -n gridos-dev
```

### Application Logs

```bash
# GridOS application logs
kubectl logs -l app=gridos -n gridos-dev --tail=100 -f

# Argo CD logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server --tail=100

# Argo Rollouts logs
kubectl logs -n argo-rollouts -l app.kubernetes.io/name=argo-rollouts --tail=100
```

---

## 🔄 Common Operations

### Manual Sync (Override Auto-Sync)

```bash
# Via CLI
argocd app sync gridos-dev

# Via UI
# Click on application → Sync → Synchronize
```

### Rollback to Previous Version

```bash
# Via Argo Rollouts
kubectl argo rollouts undo rollout gridos -n gridos-dev

# Or via Argo CD (rollback to specific Git commit)
argocd app rollback gridos-dev <history-id>

# List history IDs
argocd app history gridos-dev
```

### Pause Auto-Sync

```bash
# Pause
argocd app set gridos-dev --sync-policy none

# Resume
argocd app set gridos-dev --sync-policy automated
```

### Promote Canary Manually

```bash
# Skip analysis and promote immediately
kubectl argo rollouts promote gridos -n gridos-dev
```

### Abort Rollout

```bash
# Abort and rollback
kubectl argo rollouts abort rollout gridos -n gridos-dev
```

---

## 🛠️ Troubleshooting

### Argo CD Not Syncing

**Symptom:** Application shows "OutOfSync" but doesn't sync

**Check:**
```bash
# Check application status
argocd app get gridos-dev

# Check Argo CD server logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server --tail=100

# Check sync policy
argocd app get gridos-dev -o json | jq '.spec.syncPolicy'
```

**Fix:**
```bash
# Manual sync
argocd app sync gridos-dev

# Hard refresh (re-fetch from Git)
argocd app get gridos-dev --hard-refresh
```

### GitHub Authentication Failed

**Symptom:** "repository not accessible: authentication failed"

**Check:**
```bash
# Check GitHub secret
kubectl get secret github-repo-secret -n argocd -o yaml

# Verify token is correct
echo $GITHUB_TOKEN
```

**Fix:**
```bash
# Update GitHub secret
kubectl create secret generic github-repo-secret \
  --from-literal=username=$GITHUB_USERNAME \
  --from-literal=password=$GITHUB_TOKEN \
  --namespace argocd \
  --dry-run=client -o yaml | kubectl apply -f -

# Restart Argo CD
kubectl rollout restart deployment argocd-server -n argocd
```

### Rollout Stuck in Progressing

**Symptom:** Canary rollout stuck at certain percentage

**Check:**
```bash
# Check rollout status
kubectl argo rollouts get rollout gridos -n gridos-dev

# Check analysis runs
kubectl get analysisruns -n gridos-dev

# Check analysis details
kubectl describe analysisrun <analysis-run-name> -n gridos-dev
```

**Common causes:**
1. **Analysis failing:** Check Prometheus metrics
2. **Pods not ready:** Check pod status
3. **Service issues:** Check service endpoints

**Fix:**
```bash
# Abort and try again
kubectl argo rollouts abort rollout gridos -n gridos-dev
kubectl argo rollouts retry rollout gridos -n gridos-dev

# Or promote manually (skip analysis)
kubectl argo rollouts promote gridos -n gridos-dev
```

---

## 🎓 For Your GE Interview

### Key Talking Points

1. **Full Automation:**
   - "I automated the entire deployment with Terraform and Helm - zero manual kubectl commands"
   - "Single terraform apply deploys infrastructure + GitOps tools + applications"

2. **GitOps Principles:**
   - "Git is the single source of truth - all changes go through Git"
   - "Argo CD continuously reconciles cluster state with Git"
   - "Declarative configuration in Kustomize - no imperative commands"

3. **Progressive Delivery:**
   - "Canary deployments with automated analysis - not just traffic shifting"
   - "Prometheus metrics validate each step: success rate, latency, errors"
   - "Automatic rollback if metrics fail - protects production"

4. **Infrastructure as Code:**
   - "Modular Terraform - can deploy to dev/test/prod with different configs"
   - "State managed in Azure Storage - team collaboration ready"
   - "All resources tagged and organized - follows Azure best practices"

5. **Production Readiness:**
   - "High availability: Argo CD HA mode, multiple replicas"
   - "Security: RBAC, network policies, private endpoints"
   - "Observability: Prometheus metrics, Application Insights, Log Analytics"
   - "Disaster recovery: Blue-green capable, instant rollback"

### Demo Flow for Interview

1. **Show Infrastructure (5 min):**
   - Walk through Terraform modules
   - Explain resource organization
   - Show state management

2. **Show GitOps Setup (5 min):**
   - Argo CD UI - show applications
   - Explain reconciliation loop
   - Show Kustomize structure

3. **Live Demo (10 min):**
   - Make a change in Git (bump image tag)
   - Push to GitHub
   - Show Argo CD detecting change
   - Watch canary rollout in Rollouts Dashboard
   - Show Prometheus metrics analysis
   - Demonstrate rollback

4. **Q&A on Architecture (10 min):**
   - Discuss scaling strategies
   - Explain disaster recovery
   - Talk about multi-environment setup

---

## 🎉 Success Criteria

Your deployment is successful when:

✅ Terraform apply completes without errors  
✅ All AKS nodes are Ready  
✅ Argo CD UI accessible  
✅ Rollouts Dashboard accessible  
✅ gridos-dev application shows "Synced" and "Healthy"  
✅ Application pods are running in gridos-dev namespace  
✅ Git push triggers auto-sync in Argo CD  
✅ Canary rollout completes successfully  
✅ Prometheus analysis validates metrics  
✅ Can rollback to previous version  

**You now have a production-grade GitOps pipeline! 🚀**

---

**Questions or Issues?**

Check:
- [GITOPS_MIGRATION_COMPLETE.md](GITOPS_MIGRATION_COMPLETE.md) - Complete architecture guide
- [QUICK_REFERENCE.md](QUICK_REFERENCE.md) - Daily operations cheat sheet

Good luck with your GE Grid Solutions interview! 🎯
