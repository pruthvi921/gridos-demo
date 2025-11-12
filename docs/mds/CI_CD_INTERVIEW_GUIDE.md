# Complete CI/CD Flow - Interview Guide

## Overview: The Full Picture

You've implemented a **production-grade GitOps CI/CD pipeline** for GridOS (a SCADA monitoring system for GE Grid Solutions) using:
- **GitHub Actions** for CI/CD orchestration
- **Terraform** for infrastructure provisioning
- **Helm** for Argo CD bootstrap
- **Argo CD** for GitOps-based deployment
- **Argo Rollouts** for canary deployment strategy
- **Kustomize** for environment-specific configurations

---

## The Complete Flow (Start to Finish)

### Phase 1: Infrastructure Provisioning (One-Time Setup)

```
Developer pushes to infra branch
    ↓
GitHub Actions (infra-deploy.yml)
    ↓
Terraform validates & plans
    ↓
Manual approval (test/prod)
    ↓
Terraform provisions Azure resources:
    - AKS cluster (Kubernetes)
    - PostgreSQL database
    - VNet, subnets, NSGs
    - Application Gateway (ingress)
    ↓
Bootstrap script runs (install-argocd.sh)
    ↓
Helm installs Argo CD + Argo Rollouts in AKS
    ↓
Infrastructure ready ✅
```

**Key Interview Point:** *"We use Terraform for immutable infrastructure, then bootstrap GitOps tools via Helm, creating a declarative pipeline where infrastructure and applications are both managed as code."*

---

### Phase 2: Application CI/CD (Continuous Flow)

#### Step-by-Step Explanation

```
┌─────────────────────────────────────────────────────────────────┐
│  STAGE 1: CODE COMMIT                                           │
└─────────────────────────────────────────────────────────────────┘

Developer commits code to feature branch
    ↓
git push origin feature/new-scada-feature
    ↓
GitHub Actions triggers ci-cd.yml workflow

┌─────────────────────────────────────────────────────────────────┐
│  STAGE 2: BUILD & QUALITY GATES                                 │
└─────────────────────────────────────────────────────────────────┘

1. Build Docker Image
   - Multi-stage Dockerfile
   - Build application with dependencies
   - Tag: test-{git-sha-7-chars}
   
2. Dependency Scanning
   - npm audit (moderate+ vulnerabilities)
   - Snyk scan (high+ vulnerabilities)
   - Fails if critical issues found
   
3. Unit Tests + Code Coverage
   - Jest test framework
   - 70% coverage threshold enforced
   - Generates lcov reports
   - Uploads to Codecov
   
4. Container Security Scanning
   - Trivy scans Docker image
   - Checks for OS + app vulnerabilities
   - Results → GitHub Security tab
   
5. Code Quality
   - ESLint linting
   - Style enforcement
   - No errors allowed

6. Push Image to Azure Container Registry
   - Image: gridosacr.azurecr.io/gridos:test-abc1234

┌─────────────────────────────────────────────────────────────────┐
│  STAGE 3: GITOPS COMMIT                                         │
└─────────────────────────────────────────────────────────────────┘

Update Manifests Job:
    ↓
1. Determine environment (dev/test based on branch)
2. Update Kustomize overlay with new image tag
   File: applications/gridos/overlays/dev/kustomization.yaml
   
   images:
   - name: gridos
     newTag: test-abc1234  # ← Updated here
     
3. Git commit & push manifest change
   Commit: "chore: update gridos dev image to test-abc1234"
   
4. Push to main repository

┌─────────────────────────────────────────────────────────────────┐
│  STAGE 4: ARGO CD DETECTS CHANGE                                │
└─────────────────────────────────────────────────────────────────┘

Argo CD monitors Git repository (every 3 minutes)
    ↓
Detects manifest change in applications/gridos/overlays/dev/
    ↓
Application status: "OutOfSync"
    ↓
Auto-sync enabled → Argo CD starts sync
    ↓
Applies Kustomize manifests to AKS cluster

┌─────────────────────────────────────────────────────────────────┐
│  STAGE 5: CANARY DEPLOYMENT (Argo Rollouts)                     │
└─────────────────────────────────────────────────────────────────┘

Instead of standard Kubernetes Deployment, we use Argo Rollout:

Step 1: Initial State
    - Stable version: v1.0.0 (100% traffic)
    - New version: test-abc1234 (0% traffic)

Step 2: Canary Phase 1 (20% traffic)
    ↓
    Argo Rollouts creates new ReplicaSet
    ↓
    20% of traffic → new version (canary)
    80% of traffic → old version (stable)
    ↓
    Pause 5 minutes (automatic)
    ↓
    Analysis runs:
        - Success rate check (>95%)
        - Error rate check (<5%)
        - Response time (<500ms p95)
    ↓
    If analysis passes → Continue
    If analysis fails → AUTOMATIC ROLLBACK

Step 3: Canary Phase 2 (40% traffic)
    ↓
    Similar to Phase 1
    ↓
    40% new, 60% old
    ↓
    Pause + Analysis

Step 4: Canary Phase 3 (60% traffic)
    ↓
    60% new, 40% old
    ↓
    Pause + Analysis

Step 5: Canary Phase 4 (80% traffic)
    ↓
    80% new, 20% old
    ↓
    Pause + Analysis

Step 6: Full Promotion (100% traffic)
    ↓
    100% traffic → new version
    ↓
    Old version scaled down
    ↓
    Deployment complete ✅

┌─────────────────────────────────────────────────────────────────┐
│  STAGE 6: POST-DEPLOYMENT VALIDATION                            │
└─────────────────────────────────────────────────────────────────┘

GitHub Actions monitors deployment:

1. Wait for Argo CD Sync (Job 3)
   - Polls Argo CD API
   - Waits for "Synced" + "Healthy"
   - Timeout: 10 minutes

2. Monitor Rollout Progress (Job 4)
   - Watches Argo Rollout status
   - Tracks canary progression
   - Timeout: 20 minutes

3. Smoke Tests (Job 5)
   - Health check: /health
   - SCADA status: /api/v1/scada/status
   - Metrics: /metrics
   - Retry 5 times with 10s delay

4. Integration Tests (Job 6)
   - POST SCADA data
   - GET SCADA data
   - Verify database connectivity
   - Check Prometheus metrics
   - Validate alarm endpoints

5. Slack Notification (Job 8)
   - Success/failure notification
   - Includes image tag, commit SHA
   - Links to Argo CD dashboard

┌─────────────────────────────────────────────────────────────────┐
│  PRODUCTION DEPLOYMENT (Main Branch)                            │
└─────────────────────────────────────────────────────────────────┘

When code is merged to main:

1. All quality gates run (same as above)
2. Image tagged: v{build-number} (e.g., v123)
3. MANUAL APPROVAL required (GitHub Environment Protection)
   - 2+ approvers needed for prod
4. After approval → GitOps commit to prod overlay
5. Argo CD syncs to production AKS
6. Canary deployment to production
7. Smoke tests on production endpoints
8. Success notification
```

---

## Key Components Deep Dive

### 1. GitHub Actions (CI/CD Orchestration)

**File:** `.github/workflows/ci-cd.yml`

**Purpose:** Orchestrates the entire CI/CD pipeline

**Jobs:**
1. `build-and-test` - Builds image, runs tests, security scans
2. `update-manifests` - Updates Kustomize with new image tag
3. `wait-for-argocd-sync` - Monitors Argo CD deployment
4. `monitor-rollout` - Tracks Argo Rollouts canary progress
5. `smoke-tests` - Basic health validation
6. `integration-tests` - Full API validation
7. `production-approval` - Manual gate for prod
8. `notify` - Slack notifications

**Interview Talking Point:**
*"GitHub Actions handles our CI phase—building, testing, scanning. But deployment is handled by Argo CD using GitOps principles. This separation ensures our Git repository is the single source of truth, and deployments are declarative and auditable."*

---

### 2. Argo CD (GitOps Deployment)

**File:** `argocd/applications/gridos-dev.yaml`

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: gridos-dev
  namespace: argocd
spec:
  project: gridos
  source:
    repoURL: https://github.com/yourusername/sharedinfra
    targetRevision: main
    path: applications/gridos/overlays/dev  # ← Kustomize path
  destination:
    server: https://kubernetes.default.svc
    namespace: gridos
  syncPolicy:
    automated:
      prune: true      # Remove resources not in Git
      selfHeal: true   # Auto-fix drift
    syncOptions:
    - CreateNamespace=true
```

**How Argo CD Works:**

1. **Continuous Monitoring:**
   - Polls Git repo every 3 minutes
   - Compares desired state (Git) vs actual state (Kubernetes)
   - Shows "OutOfSync" if they differ

2. **Automated Sync:**
   - When change detected → applies manifests
   - Uses `kubectl apply` under the hood
   - Respects Kustomize overlays

3. **Health Assessment:**
   - Monitors resource health (Deployments, Services, etc.)
   - Reports "Healthy" when all resources ready
   - Shows "Degraded" if issues detected

4. **Self-Healing:**
   - If someone manually changes a resource in Kubernetes
   - Argo CD detects drift
   - Automatically reverts to Git state

**Interview Talking Point:**
*"Argo CD provides declarative GitOps deployments. If anyone manually changes something in Kubernetes, Argo CD self-heals back to the Git state. This prevents configuration drift and ensures Git is always the source of truth. We also get full audit trails—every deployment is a Git commit."*

---

### 3. Argo Rollouts (Canary Deployment)

**File:** `applications/gridos/base/rollout.yaml`

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: gridos
spec:
  replicas: 3
  strategy:
    canary:
      steps:
      - setWeight: 20    # 20% traffic to new version
      - pause:
          duration: 5m   # Wait 5 minutes
      - setWeight: 40
      - pause:
          duration: 5m
      - setWeight: 60
      - pause:
          duration: 5m
      - setWeight: 80
      - pause:
          duration: 5m
      - setWeight: 100   # Full rollout
      
      trafficRouting:
        istio:           # Use Istio for traffic splitting
          virtualService:
            name: gridos-vsvc
      
      analysis:
        templates:
        - templateName: success-rate
        - templateName: error-rate
        args:
        - name: service-name
          value: gridos
```

**Canary Deployment Flow:**

```
TIME    STABLE    CANARY    ACTION
──────────────────────────────────────────────────────
T+0     100%      0%        Deploy starts
T+1     80%       20%       First canary pod created
T+5     80%       20%       Analysis runs (success rate)
                            ✅ Pass: Continue
T+6     60%       40%       Increase canary weight
T+11    60%       40%       Analysis runs
                            ✅ Pass: Continue
T+12    40%       60%       Increase canary weight
T+17    40%       60%       Analysis runs
                            ✅ Pass: Continue
T+18    20%       80%       Increase canary weight
T+23    20%       80%       Analysis runs
                            ✅ Pass: Continue
T+24    0%        100%      Full promotion
                            Old pods terminated
```

**Automatic Rollback:**

If analysis fails at any step:
```
Analysis detects: Error rate > 5%
    ↓
Rollout pauses
    ↓
Argo Rollouts triggers automatic rollback
    ↓
Traffic shifts back to 100% stable version
    ↓
Canary pods scaled down
    ↓
Alert sent to Slack
    ↓
Deployment marked as "Degraded"
```

**Interview Talking Point:**
*"We use Argo Rollouts for progressive delivery with canary deployments. Instead of replacing all pods at once, we gradually shift traffic—20%, 40%, 60%, 80%, 100%. At each step, we run automated analysis checking success rates and error rates. If anything fails, Argo Rollouts automatically rolls back to the stable version. This minimizes blast radius and ensures zero-downtime deployments."*

---

### 4. Kustomize (Environment Management)

**Structure:**
```
applications/gridos/
├── base/                          # Common manifests
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   ├── configmap.yaml
│   ├── rollout.yaml              # Canary strategy
│   ├── hpa.yaml                  # Autoscaling
│   ├── analysis-templates.yaml   # Analysis rules
│   └── kustomization.yaml
└── overlays/
    ├── dev/
    │   └── kustomization.yaml    # Dev-specific config
    ├── test/
    │   └── kustomization.yaml    # Test-specific config
    └── prod/
        └── kustomization.yaml    # Prod-specific config
```

**Dev Overlay Example:**
```yaml
# applications/gridos/overlays/dev/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: gridos

resources:
- ../../base

images:
- name: gridos
  newName: gridosacr.azurecr.io/gridos
  newTag: test-abc1234  # ← CI updates this

replicas:
- name: gridos
  count: 2  # Dev uses 2 replicas

configMapGenerator:
- name: gridos-config
  behavior: merge
  literals:
  - LOG_LEVEL=debug       # Dev uses debug logging
  - ENVIRONMENT=dev
  - DB_HOST=postgres-dev.postgres.svc.cluster.local

patches:
- patch: |-
    - op: replace
      path: /spec/template/spec/containers/0/resources/requests/cpu
      value: 250m  # Lower CPU in dev
  target:
    kind: Rollout
    name: gridos
```

**How Kustomize Works:**

1. **Base Layer:** Common configuration for all environments
2. **Overlay Layer:** Environment-specific patches
3. **Image Tag Update:** CI updates `newTag` in overlay
4. **Kustomize Build:** Merges base + overlay
5. **Argo CD Apply:** Applies final manifests to cluster

**Interview Talking Point:**
*"We use Kustomize to manage environment-specific configurations without duplicating manifests. The base layer has common resources, and overlays patch them for dev/test/prod—different replicas, resource limits, log levels, database endpoints. When CI updates the image tag in an overlay, Argo CD automatically applies the merged configuration to the correct environment."*

---

### 5. Helm (Bootstrap Tooling)

**File:** `scripts/install-argocd.sh`

```bash
#!/bin/bash
# Bootstrap Argo CD using Helm

helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Install Argo CD
helm install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  --values argocd/helm-values/argocd-values.yaml \
  --version 5.51.6

# Install Argo Rollouts
helm install argo-rollouts argo/argo-rollouts \
  --namespace argo-rollouts \
  --create-namespace \
  --version 2.34.3

# Wait for Argo CD to be ready
kubectl wait --for=condition=available \
  --timeout=300s \
  deployment/argocd-server \
  -n argocd
```

**Helm Values Example:**
```yaml
# argocd/helm-values/argocd-values.yaml
server:
  ingress:
    enabled: true
    hosts:
    - argocd.gridos.example.com
    
  config:
    repositories: |
      - type: git
        url: https://github.com/yourusername/sharedinfra
        
controller:
  metrics:
    enabled: true  # Prometheus metrics
    
notifications:
  enabled: true
  slack:
    token: ${SLACK_TOKEN}
```

**Why Helm for Bootstrap?**

- ✅ Simplifies Argo CD installation (single command)
- ✅ Manages complex Kubernetes resources
- ✅ Supports upgrades easily
- ✅ Provides values-based configuration

**After Bootstrap:**
- Argo CD runs in cluster
- Monitors Git repository
- Manages all application deployments via GitOps

**Interview Talking Point:**
*"We use Helm only for bootstrapping GitOps tools like Argo CD and Argo Rollouts. Once Argo CD is running, it takes over and manages all application deployments declaratively via Git. Helm gives us an easy, repeatable way to install these tools with specific configurations."*

---

## Complete Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                         DEVELOPER                                   │
│                              ↓                                       │
│                     git push feature/xyz                             │
└─────────────────────────────────────────────────────────────────────┘
                               ↓
┌─────────────────────────────────────────────────────────────────────┐
│                      GITHUB REPOSITORY                              │
│  ┌─────────────────┐  ┌──────────────────┐  ┌──────────────────┐  │
│  │  Application    │  │  Kubernetes      │  │  Terraform       │  │
│  │  Source Code    │  │  Manifests       │  │  Infrastructure  │  │
│  └─────────────────┘  └──────────────────┘  └──────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
         ↓                        ↑                       ↓
         ↓                        ↑                       ↓
┌────────────────────┐   ┌───────────────┐   ┌─────────────────────┐
│  GITHUB ACTIONS    │   │   ARGO CD     │   │  TERRAFORM CLOUD    │
│  (CI/CD)           │   │  (GitOps)     │   │  (Infra Mgmt)       │
│                    │   │               │   │                     │
│  1. Build Image    │   │  Monitors Git │   │  Provisions:        │
│  2. Run Tests      │   │  Syncs K8s    │   │  - AKS Cluster      │
│  3. Security Scan  │   │  Self-heals   │   │  - PostgreSQL       │
│  4. Push to ACR    │───┼──→Updates Tag │   │  - VNet/Subnets     │
│  5. Update Git     │   │               │   │  - App Gateway      │
└────────────────────┘   └───────────────┘   └─────────────────────┘
                                  ↓                       ↓
                                  ↓                       ↓
                         ┌────────────────────────────────────────┐
                         │      AZURE KUBERNETES SERVICE (AKS)    │
                         │                                        │
                         │  ┌──────────────────────────────────┐ │
                         │  │      ARGO ROLLOUTS (Canary)      │ │
                         │  │                                  │ │
                         │  │  Stable Pods ████░░ Canary Pods │ │
                         │  │  (80% traffic)   (20% traffic)  │ │
                         │  │                                  │ │
                         │  │  Analysis: ✅ Success Rate OK   │ │
                         │  │           ✅ Error Rate OK      │ │
                         │  └──────────────────────────────────┘ │
                         │                                        │
                         │  ┌──────────────┐  ┌──────────────┐  │
                         │  │  Application │  │  PostgreSQL  │  │
                         │  │  Pods        │──│  Database    │  │
                         │  └──────────────┘  └──────────────┘  │
                         └────────────────────────────────────────┘
                                          ↓
                                          ↓
                         ┌────────────────────────────────┐
                         │   APPLICATION GATEWAY (WAF)    │
                         │   https://gridos.example.com   │
                         └────────────────────────────────┘
                                          ↓
                                          ↓
                                     END USERS
```

---

## Interview Story: Walk Through a Deployment

### Scenario: Deploying a New SCADA Feature

**Interviewer:** *"Walk me through what happens when you deploy a new feature."*

**Your Answer:**

*"Sure! Let me walk through a real example. Say I'm adding a new alarm threshold feature for the SCADA system."*

### Step 1: Development
*"I create a feature branch and write the code:"*
```bash
git checkout -b feature/alarm-threshold
# Write code...
git add .
git commit -m "feat: add configurable alarm thresholds"
git push origin feature/alarm-threshold
```

### Step 2: CI Pipeline Triggers
*"GitHub Actions immediately kicks off our CI/CD pipeline. First, it runs our quality gates:"*

- **Build:** Creates a Docker image tagged `test-a1b2c3d` (based on git SHA)
- **Dependency Scan:** npm audit checks for vulnerable packages, Snyk does deeper analysis
- **Unit Tests:** Jest runs all tests with 70% coverage threshold
- **Security Scan:** Trivy scans the Docker image for OS and application vulnerabilities
- **Linting:** ESLint ensures code quality
- **Push to ACR:** Image goes to Azure Container Registry

*"If ANY of these fail, the pipeline stops. No bad code reaches our clusters."*

### Step 3: GitOps Commit
*"Once the image passes all gates, GitHub Actions updates our Kustomize manifest:"*

```yaml
# applications/gridos/overlays/dev/kustomization.yaml
images:
- name: gridos
  newTag: test-a1b2c3d  # ← Automated update
```

*"This creates a Git commit: 'chore: update gridos dev image to test-a1b2c3d'. The key point here is that deployment is triggered by a Git commit, not by the CI tool directly. This is GitOps."*

### Step 4: Argo CD Detects Change
*"Argo CD polls our Git repository every 3 minutes. When it detects the manifest change, it shows the app as 'OutOfSync'."*

*"We have auto-sync enabled, so Argo CD immediately applies the new manifests to our dev AKS cluster. It uses Kustomize to merge our base manifests with the dev overlay, then applies them with kubectl."*

### Step 5: Canary Deployment Begins
*"Here's where it gets interesting. Instead of a standard Kubernetes Deployment, we use Argo Rollouts for progressive delivery."*

**Phase 1 (20% canary):**
- Argo Rollouts creates 1 new pod with the new image
- Istio routes 20% of traffic to the new pod
- 80% still goes to the stable version
- Pauses for 5 minutes
- Runs analysis: checks success rate, error rate, response times
- **If analysis passes:** Continues to next phase
- **If analysis fails:** Automatic rollback

**Phases 2-4 (40%, 60%, 80%):**
- Same process, gradually increasing traffic
- Each phase has automated analysis
- Any failure triggers rollback

**Phase 5 (100%):**
- All traffic to new version
- Old pods scaled down
- Deployment complete!

### Step 6: Post-Deployment Validation
*"Meanwhile, GitHub Actions is monitoring the deployment:"*

1. **Waits for Argo CD sync** (polls Argo CD API)
2. **Monitors rollout** (watches Argo Rollouts status)
3. **Runs smoke tests:**
   - `/health` endpoint
   - `/api/v1/scada/status`
   - `/metrics` for Prometheus
4. **Runs integration tests:**
   - POSTs SCADA data to the API
   - GETs data back
   - Verifies database connectivity
   - Checks new alarm threshold endpoints
5. **Sends Slack notification:** "✅ gridos-dev deployed successfully!"

### Step 7: Merge to Main (Production)
*"Once the feature is validated in dev, I create a PR to main:"*

```bash
git checkout main
git pull
git merge feature/alarm-threshold
git push
```

*"This triggers the same pipeline, but with two key differences:"*

1. **Image tag:** `v123` (production versioning)
2. **Manual approval:** GitHub Environment Protection requires 2+ approvers

*"After approval, the same GitOps flow happens—manifest update, Argo CD sync, canary deployment—but to our production AKS cluster."*

### Step 8: Monitoring
*"Post-deployment, we monitor:"*
- Prometheus metrics in Grafana
- Argo CD dashboard for sync status
- Argo Rollouts dashboard for canary progress
- Application logs for errors
- SCADA data flow for anomalies

### If Something Goes Wrong
*"If we detect issues in production, we have several options:"*

1. **Automatic rollback:** If analysis fails during canary, Argo Rollouts rolls back
2. **Manual rollback:** We can click 'Rollback' in Argo Rollouts UI
3. **Git revert:** Revert the manifest commit, Argo CD syncs back to previous version
4. **Emergency:** Manually scale down canary pods while investigating

*"The beauty of GitOps is that rollback is just another Git operation. We revert the commit, and Argo CD applies the previous state."*

---

## Key Benefits (Interview Highlights)

### 1. Declarative Deployments
- ✅ Git is single source of truth
- ✅ Every deployment is a Git commit (full audit trail)
- ✅ Easy rollbacks (just git revert)
- ✅ No imperative kubectl commands

### 2. Progressive Delivery
- ✅ Canary deployments minimize blast radius
- ✅ Automated analysis catches issues early
- ✅ Automatic rollback on failure
- ✅ Zero-downtime deployments

### 3. Self-Healing
- ✅ Argo CD detects manual changes
- ✅ Automatically reverts to Git state
- ✅ Prevents configuration drift
- ✅ Ensures consistency

### 4. Multi-Environment Management
- ✅ Kustomize overlays for dev/test/prod
- ✅ Environment-specific configurations
- ✅ No manifest duplication
- ✅ Easy to maintain

### 5. Security & Quality
- ✅ Multiple security scans (dependencies + containers)
- ✅ Code coverage enforcement
- ✅ Integration tests validate real environments
- ✅ Manual approval gates for production

### 6. Observability
- ✅ Argo CD UI shows sync status
- ✅ Argo Rollouts UI shows canary progress
- ✅ Prometheus metrics exposed
- ✅ Slack notifications
- ✅ GitHub Security tab shows vulnerabilities

---

## Common Interview Questions & Answers

### Q1: "Why use GitOps instead of pushing directly from CI?"

**Answer:**
*"GitOps provides declarative, auditable deployments. Every change is a Git commit, giving us full history. If our CI tool goes down, Argo CD keeps running. If someone manually changes Kubernetes, Argo CD self-heals. Rollbacks are simple git reverts. Plus, we get true separation of concerns—CI handles build/test, Git handles deployment."*

### Q2: "What happens if a canary deployment fails?"

**Answer:**
*"Argo Rollouts runs automated analysis at each canary step—checking success rates, error rates, response times. If any metric crosses a threshold, the rollout pauses and automatically rolls back. Traffic shifts back to 100% stable version, canary pods are scaled down, and we get a Slack alert. The old stable version continues running, so there's zero downtime."*

### Q3: "How do you handle database migrations?"

**Answer:**
*"We use init containers in Kubernetes that run before the app container starts. The init container runs migrations using a tool like Flyway or Liquibase. For canary deployments, migrations run before the first canary pod starts. Since we use backward-compatible migrations, old pods can still work with the new schema during the canary phase. For breaking changes, we'd use a maintenance window or blue-green deployment."*

### Q4: "Why both Helm and Kustomize?"

**Answer:**
*"Helm is only for bootstrapping GitOps tools—Argo CD, Argo Rollouts. These are complex applications with many resources, and Helm makes installation simple. Once they're running, we use Kustomize for application deployments because it's simpler, more declarative, and better suited for environment-specific patches. Kustomize doesn't require a templating language and works directly with YAML."*

### Q5: "How do you ensure infrastructure and application deployments are coordinated?"

**Answer:**
*"Terraform provisions infrastructure first—AKS, PostgreSQL, networking. Then our bootstrap script (install-argocd.sh) uses Helm to deploy Argo CD. Argo CD then manages application deployments via GitOps. We have separate pipelines: infra-deploy.yml for Terraform, ci-cd.yml for applications. This separation prevents accidental infrastructure changes during app deployments. Both use Git as source of truth."*

### Q6: "What's your rollback strategy?"

**Answer:**
*"We have multiple rollback mechanisms:*
1. *Automatic: Argo Rollouts rolls back if analysis fails during canary*
2. *Git revert: Revert the manifest commit, Argo CD syncs previous version*
3. *Manual: Click rollback in Argo Rollouts UI*
4. *Emergency: Update Kustomize to previous image tag, commit and push*

*The fastest is automatic rollback—happens in seconds. Git revert takes ~3 minutes (Argo CD sync interval). All rollbacks are tracked in Git history."*

### Q7: "How do you test this pipeline?"

**Answer:**
*"Multiple test layers:*
- *Unit tests (70% coverage) run in CI*
- *Integration tests run against deployed dev environment*
- *Smoke tests validate basic health after deployment*
- *Canary analysis continuously monitors metrics*
- *Manual testing in dev before promoting to prod*

*We also test infrastructure changes using Terraform plan in a reusable workflow (infra-test.yml) with TFLint, Checkov, and validate steps."*

---

## Visual Reference: Your Tech Stack

```
┌──────────────────────────────────────────────────────────┐
│                    FULL STACK                            │
├──────────────────────────────────────────────────────────┤
│  Infrastructure:                                         │
│  • Terraform (IaC)                                       │
│  • Azure (Cloud Provider)                                │
│  • AKS (Kubernetes)                                      │
│  • PostgreSQL (Database)                                 │
│  • Application Gateway (Ingress/WAF)                     │
├──────────────────────────────────────────────────────────┤
│  CI/CD:                                                  │
│  • GitHub Actions (CI orchestration)                     │
│  • Docker (Containerization)                             │
│  • Azure Container Registry (Image storage)              │
├──────────────────────────────────────────────────────────┤
│  GitOps:                                                 │
│  • Argo CD (Declarative deployments)                     │
│  • Argo Rollouts (Progressive delivery)                  │
│  • Helm (Bootstrap tooling)                              │
│  • Kustomize (Environment management)                    │
├──────────────────────────────────────────────────────────┤
│  Testing & Security:                                     │
│  • Jest (Unit tests + coverage)                          │
│  • Trivy (Container scanning)                            │
│  • npm audit + Snyk (Dependency scanning)                │
│  • ESLint (Code quality)                                 │
│  • Codecov (Coverage tracking)                           │
├──────────────────────────────────────────────────────────┤
│  Observability:                                          │
│  • Prometheus (Metrics)                                  │
│  • Grafana (Visualization)                               │
│  • Slack (Notifications)                                 │
│  • GitHub Security (Vulnerability reports)               │
└──────────────────────────────────────────────────────────┘
```

---

## Best Practices Implemented

✅ **Separation of Concerns:** CI builds/tests, Git triggers deployments  
✅ **Immutable Infrastructure:** Terraform provisions, never modifies  
✅ **Progressive Delivery:** Canary deployments with automated analysis  
✅ **Self-Healing:** Argo CD prevents configuration drift  
✅ **Security First:** Multiple scanning layers (deps, containers, code)  
✅ **Environment Parity:** Same pipeline for dev/test/prod  
✅ **Audit Trail:** Every change tracked in Git  
✅ **Automated Testing:** Unit, integration, smoke tests  
✅ **Zero Downtime:** Canary deployments + automatic rollback  
✅ **Infrastructure as Code:** Everything defined declaratively  

---

## Closing Statement for Interview

*"This architecture represents production-grade DevOps practices for a critical SCADA monitoring system. We've implemented GitOps for declarative, auditable deployments; progressive delivery with canary deployments to minimize risk; comprehensive testing and security scanning at every stage; and self-healing infrastructure that prevents configuration drift. The result is a reliable, secure, and maintainable CI/CD pipeline that can deploy multiple times per day with confidence."*

---

## Quick Reference: File Locations

```
sharedinfra/
├── .github/workflows/
│   ├── ci-cd.yml              # Application CI/CD pipeline
│   ├── infra-deploy.yml       # Infrastructure deployment
│   └── infra-test.yml         # Infrastructure testing
├── terraform/
│   └── environments/
│       ├── dev/               # Dev infrastructure
│       ├── test/              # Test infrastructure
│       └── prod/              # Prod infrastructure
├── applications/gridos/
│   ├── base/                  # Common Kubernetes manifests
│   └── overlays/              # Environment-specific configs
│       ├── dev/
│       ├── test/
│       └── prod/
├── argocd/
│   ├── applications/          # Argo CD app definitions
│   ├── projects/              # Argo CD project configs
│   └── helm-values/           # Helm values for Argo CD
├── scripts/
│   └── install-argocd.sh      # Bootstrap script
├── tests/
│   └── integration/           # Integration test suite
└── docs/
    ├── GITOPS_COMPLETE_FLOW.md
    ├── BRANCHING_STRATEGY.md
    ├── TESTING_GUIDE.md
    └── CI_CD_INTERVIEW_GUIDE.md  # This file
```

---

**You're ready for the interview! 🚀**

Practice explaining this flow out loud. Draw the diagram on a whiteboard. Be ready to deep-dive into any component. Good luck!
