# GitOps Complete Flow - Interview Guide

## Overview
This document explains the complete GitOps implementation using the industry-standard two-stage bootstrap approach.

---

## Three-Stage Architecture

### Stage 1: Infrastructure (Terraform)
**Purpose:** Deploy all Azure infrastructure  
**Tool:** Terraform  
**Managed By:** GitHub Actions (`infra-deploy.yml`)

```
terraform/
├── environments/
│   ├── dev/
│   │   ├── backend.tf      # Remote state config
│   │   ├── versions.tf     # Terraform + provider versions
│   │   ├── providers.tf    # Azure provider config
│   │   ├── main.tf         # Resources + modules
│   │   ├── variables.tf    # Variable declarations
│   │   └── outputs.tf      # Output values
│   ├── test/
│   └── prod/
└── modules/
    ├── networking/         # VNet, subnets, NSG
    ├── kubernetes/         # AKS cluster
    ├── database/           # PostgreSQL
    └── app-gateway/        # Application Gateway (ingress)
```

**What Gets Created:**
- ✅ Resource Groups
- ✅ Virtual Networks + Subnets
- ✅ AKS Cluster (with node pools)
- ✅ Azure Container Registry (ACR)
- ✅ PostgreSQL Database
- ✅ Application Gateway
- ✅ Key Vault
- ✅ Log Analytics Workspace

**Deployment:**
```bash
# Triggered automatically via GitHub Actions
# Or manually via:
terraform init -backend-config=...
terraform plan -var-file=dev.tfvars
terraform apply -var-file=dev.tfvars
```

---

### Stage 2: Bootstrap (One-Time Helm)
**Purpose:** Install Argo CD into the cluster  
**Tool:** Helm  
**Managed By:** Manual script (one-time operation)  
**File:** `scripts/install-argocd.sh`

**Why Not Terraform?**
- ❌ Creates circular dependencies
- ❌ Violates GitOps principles (Argo CD should manage apps, not be managed)
- ❌ Terraform state would conflict with Argo CD's state
- ✅ Industry standard is Helm-based bootstrap

**Bootstrap Process:**
```bash
# Step 1: Connect to AKS
az aks get-credentials --resource-group dev-gridos-rg --name dev-gridos-aks

# Step 2: Run bootstrap script
cd /c/Users/ptkad/source/repos/sharedinfra
./scripts/install-argocd.sh
```

**What the Script Does:**
1. Validates prerequisites (kubectl, helm)
2. Adds Argo Helm repo
3. Installs Argo CD (HA mode) using `argocd/helm-values/argocd-values.yaml`
4. Installs Argo Rollouts (for canary deployments)
5. Creates Argo CD Applications (tells Argo what to manage)
6. Displays admin password

**Configuration:** `argocd/helm-values/argocd-values.yaml`
```yaml
# Production-grade HA configuration
server:
  replicas: 2              # High availability
  autoscaling: true        # Scale 2-5 based on load
  
repoServer:
  replicas: 2              # HA for Git sync
  
controller:
  replicas: 2              # HA for reconciliation

redis-ha:
  enabled: true            # Redis HA for caching
  replicas: 3
```

---

### Stage 3: GitOps (Continuous)
**Purpose:** Manage all application deployments via Git  
**Tool:** Argo CD  
**Managed By:** Git commits (declarative)

**Directory Structure:**
```
applications/
└── gridos/
    ├── base/                      # Base manifests (DRY)
    │   ├── kustomization.yaml     # Kustomize config
    │   ├── deployment.yaml        # Base deployment
    │   ├── service.yaml           # Base service
    │   ├── ingress.yaml           # Base ingress
    │   ├── config.yaml            # ConfigMap
    │   ├── rollout.yaml           # Argo Rollout (canary)
    │   ├── autoscaling.yaml       # HPA
    │   └── analysis-templates.yaml # Metrics analysis
    └── overlays/                  # Environment-specific
        ├── dev/
        │   └── kustomization.yaml # Dev overrides
        ├── test/
        │   └── kustomization.yaml # Test overrides
        └── prod/
            └── kustomization.yaml # Prod overrides

argocd/
├── applications/                  # Argo CD Applications
│   ├── gridos-dev.yaml           # Dev app definition
│   ├── gridos-test.yaml          # Test app definition
│   └── gridos-prod.yaml          # Prod app definition
└── projects/
    └── gridos-project.yaml        # RBAC & policies
```

---

## Complete Developer Flow

### 1. Code Change
Developer pushes code to feature branch:
```bash
git checkout -b feature/new-scada-widget
# Make changes to src/
git commit -m "feat: add new SCADA widget"
git push origin feature/new-scada-widget
```

### 2. CI Pipeline Triggers (`.github/workflows/ci-cd.yml`)
GitHub Actions automatically:
1. **Builds Docker image**
   ```bash
   docker build -t devgridosacr.azurecr.io/gridos:dev-abc1234 .
   ```
2. **Runs tests**
   - Unit tests
   - Integration tests
   - Security scans
3. **Pushes to ACR**
   ```bash
   docker push devgridosacr.azurecr.io/gridos:dev-abc1234
   ```
4. **Updates Kustomize manifest**
   ```bash
   cd applications/gridos/overlays/dev
   kustomize edit set image \
     gridosacr.azurecr.io/gridos=devgridosacr.azurecr.io/gridos:dev-abc1234
   ```
5. **Commits manifest change**
   ```bash
   git add applications/gridos/overlays/dev/kustomization.yaml
   git commit -m "chore: update dev image to dev-abc1234"
   git push
   ```

### 3. Argo CD Syncs Automatically
Argo CD detects Git change within **3 minutes** (or instantly via webhook):
```
1. Argo CD polls GitHub every 3 minutes
2. Detects kustomization.yaml change
3. Runs: kustomize build applications/gridos/overlays/dev
4. Compares with live cluster state
5. Applies difference to cluster
```

### 4. Argo Rollouts Progressive Delivery
**Canary Deployment Steps:**
```yaml
Step 1: Deploy canary pods (10% traffic) → Wait 1min
        ↓ Run analysis (check error rate, latency)
        ↓ ✅ Analysis passes

Step 2: Increase to 25% traffic → Wait 2min
        ↓ Run analysis again
        ↓ ✅ Analysis passes

Step 3: Increase to 50% traffic → Wait 3min
        ↓ Run analysis again
        ↓ ✅ Analysis passes

Step 4: Full rollout (100% traffic) → Complete
```

**If Analysis Fails:** Automatic rollback to previous version

### 5. Monitoring
View deployment status:
```bash
# Via Argo CD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Open https://localhost:8080

# Via CLI
kubectl argo rollouts get rollout gridos -n gridos --watch

# Via kubectl
kubectl get applications -n argocd
kubectl get rollouts -n gridos
```

---

## Kustomize Usage (Why We Need It)

### Problem Without Kustomize
```
❌ applications/
   ├── dev-deployment.yaml      # 95% same as test
   ├── test-deployment.yaml     # 95% same as prod
   └── prod-deployment.yaml     # 95% same as dev
```
**Issues:**
- Code duplication
- Hard to maintain
- Easy to have drift between environments

### Solution With Kustomize
```
✅ applications/gridos/
   ├── base/                    # Write once
   │   └── deployment.yaml
   └── overlays/
       ├── dev/                 # Only differences
       │   └── kustomization.yaml  (2 replicas, debug logs)
       ├── test/
       │   └── kustomization.yaml  (3 replicas, info logs)
       └── prod/
           └── kustomization.yaml  (5 replicas, warn logs, strict security)
```

**Example Dev Override:**
```yaml
# applications/gridos/overlays/dev/kustomization.yaml
resources:
- ../../base

replicas:
- name: gridos
  count: 2              # Dev uses 2 replicas

images:
- name: gridosacr.azurecr.io/gridos
  newTag: dev-abc1234   # Updated by CI

patches:
- target:
    kind: ConfigMap
    name: gridos-config
  patch: |-
    - op: replace
      path: /data/log-level
      value: debug        # Dev uses debug logging
```

**Build Result:**
```bash
kustomize build applications/gridos/overlays/dev
# Outputs: base + dev overrides = complete manifests
```

---

## Interview Talking Points

### "Why Two-Stage Bootstrap?"

> "I use a two-stage approach following industry best practices:
> 
> **Stage 1 - Infrastructure:** Terraform creates the AKS cluster, networking, and all Azure resources. This is pure infrastructure-as-code.
> 
> **Stage 2 - Bootstrap:** After the cluster is ready, I install Argo CD via Helm as a one-time operation. Argo CD runs as pods inside the cluster - it's not managed by Terraform because that would create circular dependencies and violate GitOps principles.
> 
> **Stage 3 - GitOps:** Once Argo CD is running, all application deployments are managed through Git. Developers push code, CI builds images, updates manifests, and Argo CD automatically syncs the cluster state with Git. Everything is declarative and auditable."

### "Why Not Manage Argo CD with Terraform?"

> "Managing Argo CD with Terraform creates a chicken-and-egg problem. If Terraform manages Argo CD, and Argo CD manages applications, who manages the applications if Terraform destroys Argo CD? 
> 
> The industry standard is:
> - **Terraform = Infrastructure** (nodes, networks, storage)
> - **Argo CD = Applications** (pods, services, deployments)
> 
> This separation of concerns follows the single responsibility principle and makes operations clearer."

### "Why Kustomize Instead of Helm?"

> "For applications, I prefer Kustomize over Helm because:
> 
> 1. **Simpler:** No templating language, just YAML patches
> 2. **GitOps-native:** Argo CD has built-in Kustomize support
> 3. **Auditable:** You can see exactly what changes per environment
> 4. **No package management:** No need to manage Helm releases
> 
> However, I used Helm to install Argo CD itself because that's a one-time bootstrap operation, not a continuous deployment."

### "What Happens When a Developer Commits Code?"

> "Here's the complete flow:
> 
> 1. Developer commits to feature branch
> 2. GitHub Actions builds Docker image with tag `dev-abc1234`
> 3. CI pushes image to Azure Container Registry
> 4. CI updates the Kustomize manifest with new image tag
> 5. Argo CD detects Git change within 3 minutes (or instant via webhook)
> 6. Argo CD applies changes using Argo Rollouts for progressive delivery
> 7. Rollout starts with 10% canary, runs analysis, increases traffic gradually
> 8. If metrics look good, full rollout happens automatically
> 9. If metrics fail, automatic rollback to previous version
> 
> Everything is declarative - the Git commit is the source of truth."

### "How Do You Handle Secrets?"

> "I follow the principle of least privilege:
> 
> 1. **Infrastructure secrets** (Terraform state, Azure credentials) are in GitHub Secrets
> 2. **Application secrets** (DB passwords, API keys) are in Azure Key Vault
> 3. **Kubernetes consumes secrets** via External Secrets Operator or CSI driver
> 4. **No secrets in Git** - manifests reference secret names, not values
> 
> For example, the deployment references `gridos-secrets` which is synced from Key Vault to the cluster at runtime."

### "How Do You Rollback?"

> "Three options:
> 
> 1. **Automatic:** Argo Rollouts detects failed analysis and auto-rolls back
> 2. **Git Revert:** `git revert <commit>` → Argo CD syncs old version
> 3. **Manual:** `kubectl argo rollouts undo rollout gridos -n gridos`
> 
> Option 2 is preferred because Git remains the source of truth - every change is auditable."

---

## File Locations Reference

### Infrastructure (Terraform)
- 📂 `terraform/environments/{dev,test,prod}/` - Environment configs
- 📂 `terraform/modules/` - Reusable modules
- 📄 `.github/workflows/infra-deploy.yml` - Infrastructure pipeline
- 📄 `.github/workflows/infra-test.yml` - Infrastructure tests

### Bootstrap (One-Time)
- 📄 `scripts/install-argocd.sh` - Bootstrap script
- 📄 `argocd/helm-values/argocd-values.yaml` - Argo CD config

### GitOps (Continuous)
- 📂 `applications/gridos/base/` - Base manifests
- 📂 `applications/gridos/overlays/{dev,test,prod}/` - Environment overrides
- 📂 `argocd/applications/` - Argo CD Application definitions
- 📂 `argocd/projects/` - Argo CD Projects (RBAC)
- 📄 `.github/workflows/ci-cd.yml` - Application pipeline

### Documentation
- 📄 `docs/INFRA_PIPELINE_SETUP.md` - Infrastructure setup
- 📄 `docs/BRANCHING_STRATEGY.md` - Git workflow
- 📄 `docs/GITOPS_COMPLETE_FLOW.md` - This document

---

## Quick Commands

### Infrastructure Deployment
```bash
# Automatic via GitHub Actions (push to main/develop)
# Or manual:
cd terraform/environments/dev
terraform init -backend-config="..."
terraform plan -var-file=dev.tfvars
terraform apply -var-file=dev.tfvars
```

### Bootstrap Argo CD
```bash
# One-time after infrastructure is ready
az aks get-credentials --resource-group dev-gridos-rg --name dev-gridos-aks
./scripts/install-argocd.sh
```

### View GitOps Status
```bash
# Argo CD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# CLI
kubectl get applications -n argocd
kubectl argo rollouts list rollouts -n gridos
kubectl argo rollouts get rollout gridos -n gridos --watch
```

### Deploy Application
```bash
# Just commit code - CI + Argo CD handle the rest
git add src/
git commit -m "feat: new feature"
git push

# Or manually update image
cd applications/gridos/overlays/dev
kustomize edit set image gridosacr.azurecr.io/gridos=gridosacr.azurecr.io/gridos:v123
git add . && git commit -m "chore: update dev to v123" && git push
```

### Manual Rollback
```bash
# Option 1: Git revert (recommended)
git revert HEAD
git push

# Option 2: Argo Rollouts undo
kubectl argo rollouts undo rollout gridos -n gridos

# Option 3: Argo CD rollback to previous sync
argocd app rollback gridos-dev
```

---

## Success Criteria ✅

- ✅ Terraform manages infrastructure (AKS, networking, database)
- ✅ Helm bootstraps Argo CD (one-time)
- ✅ Argo CD manages applications (continuous)
- ✅ Kustomize handles environment differences
- ✅ Argo Rollouts provides progressive delivery
- ✅ Git is single source of truth
- ✅ No manual kubectl commands for deployments
- ✅ Automatic rollback on failure
- ✅ Full audit trail via Git history

**This is production-ready GitOps! 🚀**
