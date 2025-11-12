# GitOps Best Practices - Understanding the Fundamentals

## 🎯 Your Questions Answered

### 1. How Should Argo CD Be Installed?

**❌ WRONG: Installing Argo CD via Terraform with `null_resource` + `local-exec`**
```hcl
# This is what we currently have - NOT BEST PRACTICE
resource "null_resource" "install_argocd" {
  provisioner "local-exec" {
    command = "helm install argocd ..."
  }
}
```

**✅ CORRECT: Two-Stage Approach (Industry Standard)**

#### Stage 1: Bootstrap (Terraform)
Terraform creates the infrastructure:
- AKS cluster
- Networking
- ACR
- Everything EXCEPT Argo CD

#### Stage 2: Argo CD Installation (Manual Bootstrap, Then GitOps)
```bash
# One-time bootstrap (run once after cluster creation)
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# OR via Helm (preferred)
helm install argocd argo/argo-cd -n argocd --create-namespace
```

#### Stage 3: Argo CD Manages Itself (GitOps)
After initial installation, Argo CD manages its own configuration:
```yaml
# argocd/applications/argocd-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: argocd
  namespace: argocd
spec:
  source:
    repoURL: https://github.com/your-org/sharedinfra
    path: argocd/helm-values
  destination:
    namespace: argocd
```

**Why this is better:**
- ✅ Argo CD runs as Kubernetes pods (not external script)
- ✅ Argo CD can update itself via GitOps
- ✅ All configuration in Git
- ✅ No dependency on local tools during Terraform apply

---

## 2. Helm vs Kustomize - Which to Use?

### The Confusion

You're seeing both Helm and Kustomize in the project. Here's why:

**Helm** is for:
- Installing third-party applications (Argo CD, Prometheus, Grafana)
- Applications with complex configuration options
- Applications with templating needs (lots of `{{ .Values.something }}`)

**Kustomize** is for:
- Your own applications (GridOS app)
- Environment-specific patches (dev/test/prod)
- Simpler, more declarative than Helm

### The Right Pattern (Industry Standard)

```
Use Helm for:
├── Argo CD installation
├── Argo Rollouts installation
├── Prometheus/Grafana
├── Cert-manager
├── External Secrets Operator
└── All third-party charts

Use Kustomize for:
├── Your application (GridOS)
├── Environment overlays (dev/test/prod)
└── Configuration patches
```

### Example: Your GridOS Application

**✅ CORRECT: Use Kustomize**
```
applications/gridos/
├── base/                    # Base manifests
│   ├── rollout.yaml
│   ├── service.yaml
│   └── kustomization.yaml
└── overlays/
    ├── dev/kustomization.yaml    # Dev patches
    ├── test/kustomization.yaml   # Test patches
    └── prod/kustomization.yaml   # Prod patches
```

**❌ WRONG: Creating Helm chart for GridOS**
```
charts/gridos/
├── Chart.yaml
├── values.yaml
└── templates/
    ├── deployment.yaml   # With {{ .Values.image.tag }}
    └── service.yaml      # With {{ .Values.service.port }}
```

**Why Kustomize is better for your app:**
- ✅ Simpler - just YAML patches
- ✅ No templating logic
- ✅ Easier to debug
- ✅ GitOps-friendly (clear diffs in Git)

---

## 3. The Complete Production Architecture

### The Right Way

```
┌─────────────────────────────────────────────────────────┐
│ 1. Infrastructure Layer (Terraform)                     │
│    - Creates AKS cluster                                │
│    - Creates networking, ACR, etc.                      │
│    - Does NOT install Argo CD                           │
│    - Outputs: cluster endpoint, credentials             │
└─────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────┐
│ 2. Bootstrap Layer (One-time manual)                    │
│    - Install Argo CD via Helm                           │
│    - Create initial Application for "app-of-apps"       │
│    - From this point, everything is GitOps              │
└─────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────┐
│ 3. GitOps Layer (Argo CD manages everything)            │
│    ┌─────────────────────────────────────────────────┐ │
│    │ App-of-Apps Pattern                              │ │
│    │                                                   │ │
│    │ argocd/applications/app-of-apps.yaml             │ │
│    │   ├── infrastructure-apps (Helm)                 │ │
│    │   │   ├── prometheus                             │ │
│    │   │   ├── grafana                                │ │
│    │   │   ├── cert-manager                           │ │
│    │   │   └── external-secrets                       │ │
│    │   │                                               │ │
│    │   └── business-apps (Kustomize)                  │ │
│    │       ├── gridos-dev                             │ │
│    │       ├── gridos-test                            │ │
│    │       └── gridos-prod                            │ │
│    └─────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────┐
│ 4. Application Layer (Kubernetes)                       │
│    - All apps running in cluster                        │
│    - Managed by Argo CD                                 │
│    - Updates via Git commits                            │
└─────────────────────────────────────────────────────────┘
```

---

## 4. The "App-of-Apps" Pattern (Best Practice)

### What is App-of-Apps?

Instead of creating many Application CRDs manually, create ONE master Application that creates all others.

**Structure:**
```
argocd/
├── bootstrap/
│   └── app-of-apps.yaml          # Master application
│
├── apps/
│   ├── infrastructure/           # Helm-based apps
│   │   ├── argocd.yaml          # Argo CD manages itself!
│   │   ├── argo-rollouts.yaml
│   │   ├── prometheus.yaml
│   │   ├── grafana.yaml
│   │   └── cert-manager.yaml
│   │
│   └── business/                 # Your applications
│       ├── gridos-dev.yaml      # Kustomize-based
│       ├── gridos-test.yaml
│       └── gridos-prod.yaml
│
└── helm-values/                  # Helm values for infra apps
    ├── argocd/
    │   └── values.yaml
    ├── prometheus/
    │   └── values.yaml
    └── grafana/
        └── values.yaml
```

**The master app:**
```yaml
# argocd/bootstrap/app-of-apps.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: app-of-apps
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/sharedinfra
    targetRevision: main
    path: argocd/apps
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

**Apply only once:**
```bash
kubectl apply -f argocd/bootstrap/app-of-apps.yaml
```

Now Argo CD manages everything, including itself!

---

## 5. Complete Best Practice Setup

### Step-by-Step Implementation

#### Step 1: Terraform (Infrastructure Only)

```hcl
# terraform/environments/dev/main.tf
module "kubernetes" {
  source = "../../modules/kubernetes"
  # ... AKS configuration
}

module "application_gateway" {
  source = "../../modules/application_gateway"
  # ... App Gateway configuration
}

# NO Argo CD installation here!
```

**Run:**
```bash
terraform apply
```

#### Step 2: Bootstrap Argo CD (One-time)

```bash
# Get AKS credentials
az aks get-credentials --name gridos-dev-aks --resource-group gridos-dev-rg

# Install Argo CD via Helm
helm repo add argo https://argoproj.github.io/argo-helm
helm install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  --values argocd/helm-values/argocd/values.yaml

# Wait for Argo CD to be ready
kubectl wait --for=condition=available --timeout=300s \
  deployment/argocd-server -n argocd

# Get admin password
kubectl get secret argocd-initial-admin-secret \
  -n argocd \
  -o jsonpath="{.data.password}" | base64 -d

# Apply app-of-apps (bootstraps everything else)
kubectl apply -f argocd/bootstrap/app-of-apps.yaml
```

#### Step 3: Everything Else is GitOps

From now on, all changes go through Git:

```bash
# Update application
git commit -am "Update GridOS to v1.0.1"
git push

# Argo CD syncs automatically (within 3 minutes)
# Or sync manually:
argocd app sync gridos-dev
```

---

## 6. CI/CD Pipeline Structure

### GitHub Actions (CI)

```yaml
# .github/workflows/ci.yml
name: CI Pipeline
on:
  push:
    branches: [main]

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    steps:
      - name: Build Docker image
        run: docker build -t $ACR_NAME.azurecr.io/gridos-app:${{ github.sha }}
      
      - name: Push to ACR
        run: docker push $ACR_NAME.azurecr.io/gridos-app:${{ github.sha }}
      
      - name: Update Kustomize image tag
        run: |
          cd applications/gridos/overlays/dev
          kustomize edit set image gridos-app=$ACR_NAME.azurecr.io/gridos-app:${{ github.sha }}
          git add kustomization.yaml
          git commit -m "Update image to ${{ github.sha }}"
          git push
```

### Argo CD (CD)

Argo CD watches the Git repo and syncs changes automatically. No additional pipeline needed!

```
Git Push → GitHub Actions (build) → Update manifest → Argo CD detects → Deploys
```

---

## 7. Why This Is Better Than What We Had

### Current Setup (What We Have Now)

```hcl
# ❌ Problem: Terraform installs Argo CD with null_resource
resource "null_resource" "install_argocd" {
  provisioner "local-exec" {
    command = "helm install argocd ..."  # Runs from laptop
  }
}
```

**Issues:**
- ❌ Requires local tools (helm, kubectl) during terraform apply
- ❌ Argo CD config not in Git (can't GitOps itself)
- ❌ Hard to update Argo CD (need to re-run Terraform)
- ❌ Doesn't follow GitOps principles
- ❌ Terraform state includes external commands (brittle)

### Proposed Setup (Best Practice)

```bash
# ✅ Solution 1: Terraform creates infrastructure
terraform apply

# ✅ Solution 2: Bootstrap Argo CD (one-time)
helm install argocd argo/argo-cd -n argocd --create-namespace

# ✅ Solution 3: App-of-apps bootstraps everything
kubectl apply -f argocd/bootstrap/app-of-apps.yaml

# ✅ From here, everything is GitOps
```

**Benefits:**
- ✅ Argo CD runs as Kubernetes pods (proper)
- ✅ Argo CD config in Git (GitOps itself)
- ✅ Easy to update (just commit to Git)
- ✅ Follows GitOps principles
- ✅ Terraform only manages infrastructure
- ✅ Clear separation of concerns

---

## 8. Recommended Structure

```
sharedinfra/
├── terraform/                       # Infrastructure only
│   ├── modules/
│   │   ├── kubernetes/             # AKS cluster
│   │   ├── networking/             # VNet, subnets
│   │   └── application_gateway/    # App Gateway
│   └── environments/
│       └── dev/
│           ├── main.tf             # No Argo CD here!
│           └── outputs.tf          # Cluster endpoint, etc.
│
├── argocd/
│   ├── bootstrap/
│   │   └── app-of-apps.yaml        # Master application
│   │
│   ├── apps/
│   │   ├── infrastructure/
│   │   │   ├── argocd.yaml        # Argo CD manages itself
│   │   │   ├── argo-rollouts.yaml
│   │   │   ├── prometheus.yaml
│   │   │   └── cert-manager.yaml
│   │   │
│   │   └── business/
│   │       ├── gridos-dev.yaml
│   │       ├── gridos-test.yaml
│   │       └── gridos-prod.yaml
│   │
│   └── helm-values/                # Helm values for infra
│       ├── argocd/values.yaml
│       ├── prometheus/values.yaml
│       └── cert-manager/values.yaml
│
├── applications/                    # Your applications (Kustomize)
│   └── gridos/
│       ├── base/                   # Common manifests
│       │   ├── rollout.yaml
│       │   ├── service.yaml
│       │   └── kustomization.yaml
│       │
│       └── overlays/               # Environment-specific
│           ├── dev/
│           ├── test/
│           └── prod/
│
└── .github/
    └── workflows/
        └── ci.yml                   # Build & push only
```

---

## 9. Deployment Flow (End-to-End)

### Initial Setup (One-time)

```bash
# 1. Deploy infrastructure
cd terraform/environments/dev
terraform apply

# 2. Get cluster access
az aks get-credentials --name gridos-dev-aks --resource-group gridos-dev-rg

# 3. Install Argo CD
helm repo add argo https://argoproj.github.io/argo-helm
helm install argocd argo/argo-cd -n argocd --create-namespace \
  --values ../../argocd/helm-values/argocd/values.yaml

# 4. Bootstrap app-of-apps
kubectl apply -f ../../argocd/bootstrap/app-of-apps.yaml

# Done! Everything else is automated.
```

### Daily Development

```bash
# 1. Developer makes code change
git commit -am "New feature"
git push

# 2. GitHub Actions (CI):
#    - Builds Docker image
#    - Pushes to ACR
#    - Updates Kustomize image tag in Git

# 3. Argo CD (CD):
#    - Detects Git change (within 3 min)
#    - Syncs cluster with Git
#    - Argo Rollouts performs canary

# 4. Verify
argocd app get gridos-dev
kubectl argo rollouts get rollout gridos -n gridos-dev
```

---

## 10. Summary: What Needs to Change

### Remove from Current Setup

1. ❌ Remove `terraform/environments/dev/argocd.tf` (Argo CD via Terraform)
2. ❌ Remove `argocd/install/*.yaml` (not needed with Helm)
3. ❌ Remove manual Application CRDs (use app-of-apps)

### Add to Project

1. ✅ `argocd/bootstrap/app-of-apps.yaml` - Master application
2. ✅ `argocd/apps/infrastructure/*.yaml` - Infrastructure apps (Helm-based)
3. ✅ `argocd/apps/business/*.yaml` - Business apps (Kustomize-based)
4. ✅ `argocd/helm-values/` - Helm values for infrastructure apps
5. ✅ `bootstrap.sh` - One-time setup script

### Update

1. ✅ `terraform/` - Remove Argo CD installation
2. ✅ `.github/workflows/` - Simplify to just build & update manifests
3. ✅ `README.md` - Document two-stage setup

---

## 🎯 Decision Time

**Which approach do you want?**

### Option A: Keep Current (Simpler, but not best practice)
- Terraform installs Argo CD
- Easier for demo/interview
- Good enough for showcasing

### Option B: Refactor to Best Practice (Industry standard)
- Two-stage: Terraform → Bootstrap → GitOps
- Proper separation of concerns
- Better for real production
- More impressive in interview

**What would you like to do?**

1. Keep current setup (quick demo)
2. Refactor to best practices (proper production)
3. Show me more examples before deciding

Let me know and I'll implement accordingly!
