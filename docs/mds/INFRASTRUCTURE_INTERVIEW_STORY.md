# Infrastructure + GitOps Interview Story

## 30-Second Elevator Pitch

> "I built a production-grade Azure infrastructure with complete GitOps automation for a SCADA monitoring system. The architecture follows a three-stage approach: Terraform provisions the infrastructure, Helm bootstraps Argo CD, and then everything runs via GitOps with progressive canary deployments. All infrastructure is tested before deployment, and applications use Kustomize for environment management."

---

## The Story (2-3 Minutes)

### Context & Problem
"I was tasked with building production infrastructure for GridOS, a SCADA monitoring system for GE Grid Solutions. The requirements were:
- Multi-environment deployment (dev, test, prod)
- Zero-downtime deployments
- Automated testing and validation
- Complete audit trail
- Progressive rollouts with automatic rollback

The challenge was to implement this following industry best practices while avoiding common pitfalls like Terraform managing application workloads or manual kubectl operations."

### Solution Architecture

**1. Infrastructure Layer (Terraform)**
"I designed a modular Terraform structure with three environments. The key decision was separating infrastructure concerns:

```
Infrastructure (Terraform):
├── Networking (VNet, subnets, NSG, Application Gateway)
├── Compute (AKS with system + user node pools)
├── Data (PostgreSQL with HA, Key Vault)
└── Registry (Azure Container Registry)
```

Each environment has standardized files following best practices:
- `backend.tf` - Remote state in Azure Storage
- `versions.tf` - Terraform and provider versions
- `providers.tf` - Azure provider configuration  
- `main.tf` - Resource definitions
- `variables.tf` - Input variables
- `outputs.tf` - Output values

This separation makes the code maintainable and follows the DRY principle through reusable modules."

**2. Infrastructure Testing Pipeline**
"Before any infrastructure changes deploy, they go through 8 automated tests:

1. **Terraform Format** - Code consistency
2. **TFLint** - Static analysis for all environments
3. **Checkov** - Security scanning (1000+ checks)
4. **Terraform Validate** - Syntax validation
5. **Terraform Plan** - Dry-run to catch issues
6. **Documentation Check** - Ensure README is updated
7. **Variable Validation** - No secrets in code
8. **Cost Estimation** - Track spend with Infracost

Tests run on every PR and push. Production deployments require 2+ approvals. This catches issues before they reach production."

**3. Two-Stage Bootstrap (Key Architecture Decision)**
"Here's where I made a critical design choice. Instead of using Terraform to manage Argo CD, I implemented industry-standard two-stage bootstrap:

**Stage 1:** Terraform creates infrastructure → AKS cluster ready  
**Stage 2:** Helm installs Argo CD → One-time bootstrap  
**Stage 3:** Argo CD manages applications → Continuous GitOps

Why not Terraform for Argo CD? Three reasons:
1. **Circular dependencies** - If Terraform manages Argo CD, and Argo CD manages apps, destroying the Terraform state breaks everything
2. **Violates GitOps principles** - Argo CD should be the source of truth for apps, not Terraform state
3. **Industry standard** - This is how companies like Weaveworks, Intuit, and others do it

The bootstrap script (`install-argocd.sh`) runs once, installs Argo CD in HA mode (2 replicas, Redis HA, autoscaling), and creates the initial applications."

**4. GitOps with Kustomize**
"For application deployments, I chose Kustomize over Helm because it's simpler and more GitOps-native:

```
applications/gridos/
├── base/                    # Base manifests (write once)
│   ├── deployment.yaml
│   ├── service.yaml
│   └── rollout.yaml        # Argo Rollouts for canary
└── overlays/               # Environment-specific patches
    ├── dev/                # 2 replicas, debug logs
    ├── test/               # 3 replicas, info logs
    └── prod/               # 5 replicas, strict security
```

This follows DRY - the base is defined once, and overlays only specify differences. Much cleaner than duplicating manifests or managing complex Helm values."

**5. Complete CI/CD Flow**
"When a developer commits code, here's what happens automatically:

```
1. GitHub Actions triggers
2. Builds Docker image: devgridosacr.azurecr.io/gridos:dev-abc1234
3. Runs tests (unit, integration, security)
4. Pushes to Azure Container Registry
5. Updates Kustomize manifest with new image tag
6. Commits manifest change to Git
7. Argo CD detects Git change (3min polling or instant webhook)
8. Syncs cluster state with Git
9. Argo Rollouts starts progressive deployment
```

The rollout strategy is canary-based:
- 10% traffic → Analysis (metrics check) → 25% → Analysis → 50% → Analysis → 100%
- If analysis fails at any point, automatic rollback
- Zero downtime, zero manual intervention"

**6. Branching Strategy**
"The Git workflow aligns with environments:

- `feature/*` / `develop` → Auto-deploy to dev
- `main` → Deploy to prod (requires PR + 2 approvals)

This means developers can test changes immediately in dev, but production changes require review and pass all quality gates."

### Results & Benefits

**Achieved:**
- ✅ **Zero-downtime deployments** - Canary rollouts with automatic rollback
- ✅ **Full automation** - No manual kubectl commands
- ✅ **Complete audit trail** - Every change traceable via Git
- ✅ **Infrastructure safety** - 8 tests before any deployment
- ✅ **Cost visibility** - Infracost tracking on every PR
- ✅ **Fast feedback** - Developers see changes in dev within minutes

**Key Metrics:**
- Infrastructure deployment: ~15 minutes
- Application deployment: ~5 minutes with progressive rollout
- Rollback time: <2 minutes
- Test coverage: 8 automated checks before production

### Technical Challenges & Solutions

**Challenge 1: Terraform State Management**
"Multiple engineers working on same infrastructure caused state lock conflicts.

**Solution:** Azure Storage backend with state locking, plus GitHub environment protection rules ensuring only one deployment runs at a time."

**Challenge 2: Secret Management**
"Can't store secrets in Git, but applications need them.

**Solution:** Three-layer approach:
1. Infrastructure secrets → GitHub Secrets (Azure credentials)
2. Application secrets → Azure Key Vault
3. Kubernetes → External Secrets Operator syncs from Key Vault
No secrets ever touch Git."

**Challenge 3: Application Gateway Integration**
"Argo Rollouts uses NGINX-style annotations but we use Azure Application Gateway.

**Solution:** Application Gateway Ingress Controller (AGIC) accepts the same annotations. Rollouts work seamlessly with both NGINX and AGIC."

---

## Interview Q&A Preparation

### Q: "Why split backend.tf, versions.tf, and providers.tf instead of keeping everything in main.tf?"

> "This follows Terraform best practices for several reasons:
> 
> 1. **Clarity** - Each file has one responsibility
> 2. **Reusability** - Backend config can be templated across environments
> 3. **Upgrades** - Version constraints are isolated, making provider upgrades safer
> 4. **Team collaboration** - Different team members can work on different aspects
> 
> It's the same principle as separation of concerns in software architecture."

### Q: "Why use GitHub Actions instead of Azure DevOps if you're on Azure?"

> "Several reasons:
> 
> 1. **GitOps alignment** - Everything in one place (code + pipelines + infrastructure)
> 2. **Marketplace** - Larger ecosystem of actions
> 3. **Modern YAML** - Simpler syntax than Azure DevOps
> 4. **Cost** - Free for public repos, cheaper for private
> 
> However, I'm comfortable with both. The concepts translate directly - stages become jobs, steps stay steps, secrets work the same way."

### Q: "What if Argo CD goes down? Can you still deploy?"

> "Great question. If Argo CD is down:
> 
> 1. **Existing apps keep running** - They're just Kubernetes pods
> 2. **No new syncs happen** - Cluster stays in current state
> 3. **Emergency rollback available** - Can use kubectl directly
> 4. **HA prevents this** - We run 2 Argo CD replicas + Redis HA
> 
> That said, the proper fix is to restore Argo CD, not bypass it. The bootstrap script can re-install in minutes."

### Q: "How do you handle database schema migrations in this GitOps model?"

> "Database migrations are tricky in GitOps because they're stateful. My approach:
> 
> 1. **Migration as init container** - Runs before app starts
> 2. **Idempotent migrations** - Use tools like Flyway or Liquibase that track applied migrations
> 3. **Backward compatible** - Always make migrations backward compatible for rollback
> 4. **Manual gate for prod** - Require approval before migration runs
> 
> The key is treating migrations as code (in Git) but with extra safeguards."

### Q: "Why Argo Rollouts instead of built-in Kubernetes Deployments?"

> "Deployments only do blue-green (rolling updates). Rollouts provide:
> 
> 1. **Canary deployments** - Progressive traffic shifting
> 2. **Metric-based analysis** - Automatic rollback on high error rates
> 3. **Traffic management** - Works with ingress controllers
> 4. **Pause points** - Manual approval gates in rollout
> 
> For SCADA systems where downtime means grid outages, progressive rollouts with automatic rollback are critical."

### Q: "How do you test infrastructure changes before applying to production?"

> "Three levels of testing:
> 
> 1. **Static tests** - TFLint, Checkov, terraform validate (no resources created)
> 2. **Plan review** - terraform plan shows exactly what will change
> 3. **Lower environment** - Apply to dev first, verify, then promote
> 
> Plus GitHub requires 2+ approvals for prod changes. By the time something reaches production, it's been tested extensively."

### Q: "What's your disaster recovery strategy?"

> "Multiple layers:
> 
> 1. **Infrastructure** - Terraform state in Azure Storage with versioning + soft delete
> 2. **Cluster** - AKS snapshots + etcd backups
> 3. **Applications** - Everything in Git, can redeploy anytime
> 4. **Data** - PostgreSQL automated backups + geo-redundancy
> 5. **Secrets** - Key Vault with soft delete and purge protection
> 
> Worst case: I can destroy everything and recreate from scratch in ~30 minutes using Terraform + bootstrap script."

---

## Show & Tell (Demo Flow)

If asked to demonstrate:

**1. Show Infrastructure Structure (30 seconds)**
```bash
tree terraform/environments/dev
cat terraform/environments/dev/main.tf | head -50
```
"Notice the clean separation - backend, versions, providers all in separate files."

**2. Show Infrastructure Pipeline (30 seconds)**
```bash
cat .github/workflows/infra-test.yml | grep "  - name:"
```
"Here are the 8 automated tests every infrastructure change goes through."

**3. Show GitOps Structure (30 seconds)**
```bash
tree applications/gridos
cat applications/gridos/overlays/dev/kustomization.yaml
```
"Base manifests plus environment-specific patches. Classic Kustomize pattern."

**4. Show Application Pipeline (30 seconds)**
```bash
cat .github/workflows/ci-cd.yml | head -100
```
"Build, test, push image, update manifest, let Argo CD handle deployment."

**5. Show Progressive Rollout (30 seconds)**
```bash
cat applications/gridos/base/rollout.yaml | grep -A 5 "steps:"
```
"10% → 25% → 50% → 100% with metric analysis at each step."

---

## Key Differentiators (Why This Implementation Stands Out)

1. **Infrastructure Testing** - Most people skip this. 8 automated tests before deployment.
2. **Two-Stage Bootstrap** - Proper separation of infrastructure vs applications.
3. **Kustomize over Helm** - Simpler, more auditable, better for GitOps.
4. **Progressive Rollouts** - Not just deploying, but deploying safely with canary analysis.
5. **Complete Automation** - From commit to production with zero manual steps.
6. **Production-Grade HA** - Everything is redundant (Argo CD, Redis, AKS nodes).
7. **Branching Strategy** - Aligns environments with Git branches cleanly.

---

## One-Liner Answers (For Quick Questions)

**Q: What's GitOps?**  
> "Git is the single source of truth; cluster state is synced to match Git automatically."

**Q: Terraform vs Helm for Argo CD?**  
> "Terraform for infrastructure, Helm for Argo CD bootstrap, Argo CD for applications - separation of concerns."

**Q: Why Kustomize?**  
> "Simpler than Helm, native to Argo CD, easier to audit changes per environment."

**Q: How fast is deployment?**  
> "Infrastructure: 15 min. Application: 5 min with progressive canary rollout."

**Q: Can you rollback?**  
> "Automatic via Argo Rollouts on metric failures, or git revert for manual rollback."

**Q: Where are secrets?**  
> "Azure Key Vault synced to cluster via External Secrets Operator. Never in Git."

**Q: How do you test infra?**  
> "8 automated tests: format, lint, security scan, validate, plan, docs, secrets, cost."

**Q: What if Argo CD fails?**  
> "Apps keep running. We have HA (2 replicas). Bootstrap script can re-install in minutes."

---

## Complete Workflow Explanation (Start to Finish)

### What is GridOS (The Application)

**GridOS** is a **SCADA (Supervisory Control and Data Acquisition)** monitoring system built for **GE Grid Solutions** to monitor electrical grid infrastructure in real-time.

**What it does:**
- **Monitors electrical grid equipment**: Transformers, circuit breakers, substations
- **Collects sensor data**: Voltage, current, power factor, frequency from grid devices
- **Stores time-series data**: Historical readings in PostgreSQL for trend analysis
- **Generates alarms**: When voltage exceeds thresholds, equipment failures detected
- **Provides REST APIs**: For operators to query device status, retrieve historical data
- **Exports metrics**: Prometheus metrics for monitoring system health
- **Visualizes data**: Real-time dashboards showing grid health and anomalies

**Technical Stack:**
- Node.js + Express.js (REST API)
- PostgreSQL (time-series data storage)
- Prometheus + Grafana (monitoring)
- Docker containerized
- Kubernetes orchestrated

**Why SCADA matters:** Grid operators use this to detect issues before blackouts occur, manage power distribution, and ensure grid stability across cities/regions.

---

### The Complete CI/CD Workflow (Step-by-Step)

#### **STAGE 1: Developer Commits Code**

```
Developer working on new alarm threshold feature:
├── Writes code in src/scada/alarm-service.js
├── Creates tests in tests/unit/alarm-service.test.js
├── Updates API docs
├── Commits to feature branch
└── $ git push origin feature/alarm-threshold-update
```

**Trigger:** Push to GitHub repository → GitHub Actions webhook fires immediately

---

#### **STAGE 2: GitHub Actions CI Pipeline (Build & Test)**

**File:** `.github/workflows/ci-cd.yml`

**Job 1: Build and Test (~5 minutes)**

1. **Checkout Code** (git clone)
   - Fetches all source code from repository
   - Includes Dockerfile, package.json, test files

2. **Build Docker Image** (Docker build)
   - Multi-stage build: installs dependencies, compiles code
   - Creates container image with Node.js runtime + app
   - Tagged based on branch: `gridosacr.azurecr.io/gridos:test-a1b2c3d` (git SHA)

3. **Dependency Scanning** (npm audit + Snyk)
   - **npm audit**: Scans package.json for known vulnerabilities in dependencies (e.g., Express.js security patches)
   - **Snyk**: Deeper analysis with proprietary vulnerability database
   - Fails pipeline if HIGH or CRITICAL vulnerabilities found
   - **Why:** Prevents deploying apps with known security flaws (e.g., SQL injection risks)

4. **Unit Tests with Coverage** (Jest)
   - Runs `npm test` inside Docker container
   - Executes 200+ unit tests for API endpoints, SCADA data processing, alarm logic
   - Calculates code coverage: branches, functions, lines, statements
   - **Enforces 70% coverage threshold** - fails if below
   - Generates lcov report for Codecov tracking
   - **Why:** Ensures code quality, catches regressions, proves testability

5. **Container Security Scan** (Trivy)
   - Scans Docker image for OS vulnerabilities (e.g., outdated Linux packages)
   - Checks Node.js base image for CVEs
   - Scans application dependencies again at container level
   - **Severity filter: CRITICAL, HIGH**
   - Uploads results to GitHub Security tab for tracking
   - **Why:** Container images can have vulnerabilities even if dependencies are clean

6. **Code Quality Check** (ESLint)
   - Lints JavaScript/TypeScript code
   - Enforces style guide (indentation, naming conventions)
   - Detects potential bugs (unused variables, unreachable code)
   - Fails on errors, warns on style issues
   - **Why:** Maintains consistent, maintainable codebase

7. **Push Image to Azure Container Registry**
   - Authenticates to ACR using Azure credentials (from GitHub Secrets)
   - Pushes tagged image: `gridosacr.azurecr.io/gridos:test-a1b2c3d`
   - Stored in private registry (not public Docker Hub)
   - **Why:** Secure storage, fast pulls from Azure AKS, integrated with Azure RBAC

**Output:** Docker image in ACR, all tests passed ✅

---

#### **STAGE 3: GitOps Manifest Update**

**Job 2: Update Manifests (~30 seconds)**

1. **Determine Environment**
   - `feature/*` or `develop` branch → **dev** environment
   - `main` branch → **prod** environment (requires approval)

2. **Update Kustomize Overlay**
   - **File:** `applications/gridos/overlays/dev/kustomization.yaml`
   - **Change:**
     ```yaml
     images:
     - name: gridos
       newName: gridosacr.azurecr.io/gridos
       newTag: test-a1b2c3d  # ← THIS LINE UPDATED
     ```
   - This tells Kubernetes which image version to deploy

3. **Git Commit and Push**
   - Creates commit: `chore: update gridos dev image to test-a1b2c3d`
   - Pushes to main repository
   - **Why GitOps:** Deployment triggered by Git commit, not CI tool directly
   - Creates audit trail (who deployed what, when)

**Output:** Git repository updated with new image tag

---

#### **STAGE 4: Argo CD Detects Change**

**Tool:** Argo CD (GitOps continuous deployment)

**What Argo CD does:**
- **Continuously polls Git repository** (every 3 minutes, or instant via webhook)
- **Compares desired state (Git) vs actual state (Kubernetes cluster)**
- When detects manifest change:
  - Shows application as **"OutOfSync"** in UI
  - Automatically triggers sync (because auto-sync enabled)

**Sync Process:**

1. **Runs Kustomize Build**
   ```bash
   kustomize build applications/gridos/overlays/dev/
   ```
   - Merges base manifests + dev overlay
   - Generates final Kubernetes YAML with new image tag
   - Includes: Deployment, Service, Ingress, ConfigMap, Rollout, HPA

2. **Applies to Kubernetes Cluster**
   ```bash
   kubectl apply -f generated-manifests.yaml
   ```
   - Sends manifests to AKS cluster
   - Kubernetes API receives update
   - **Rollout resource** (not standard Deployment) gets updated

3. **Monitors Resource Health**
   - Watches pods, services, ingresses
   - Reports status: Syncing → Synced → Healthy
   - Shows in Argo CD dashboard

**Why Argo CD:**
- **Declarative:** Desired state in Git, Argo CD makes it reality
- **Self-healing:** If someone manually edits a pod, Argo CD reverts to Git state
- **Audit trail:** Every deployment is a Git commit
- **Multi-environment:** One Argo CD manages dev, test, prod clusters

**Output:** New Rollout version applied to AKS cluster

---

#### **STAGE 5: Argo Rollouts Progressive Deployment**

**Tool:** Argo Rollouts (canary deployment controller)

**What Argo Rollouts does:**
- Watches **Rollout resources** (not standard Deployments)
- Implements **progressive delivery strategies** (canary, blue-green)
- Runs **automated analysis** at each step
- Handles **automatic rollback** on failures

**Canary Deployment Process:**

```
Initial State:
├── Stable version: v1.0.0 (5 pods)
└── New version: test-a1b2c3d (0 pods)
    100% traffic → stable version

T+0: Rollout Starts
├── Creates 1 canary pod with new image
├── Traffic split: 80% stable (4 pods), 20% canary (1 pod)
└── Status: Canary running

T+5min: Pause + Analysis #1
├── Queries Prometheus metrics:
│   ├── Success rate: 98% (threshold: >95%) ✅
│   ├── Error rate: 1.5% (threshold: <5%) ✅
│   └── Response time p95: 340ms (threshold: <500ms) ✅
├── Analysis passes → Continue
└── Creates 1 more canary pod

T+6min: 40% Canary
├── Traffic split: 60% stable (3 pods), 40% canary (2 pods)
└── Status: Progressive rollout

T+11min: Pause + Analysis #2
├── Same metrics check
├── Analysis passes → Continue
└── Creates 1 more canary pod

T+12min: 60% Canary
├── Traffic split: 40% stable (2 pods), 60% canary (3 pods)
└── Status: Near completion

T+17min: Pause + Analysis #3
├── Metrics check
├── Analysis passes → Continue
└── Creates 2 more canary pods

T+18min: 100% Canary (Full Promotion)
├── All 5 pods running new version
├── Old stable pods scaled down and terminated
├── New version becomes "stable"
└── Status: Rollout complete ✅

Total Time: ~20 minutes (including pauses and analysis)
```

**If Analysis Fails (Automatic Rollback):**
```
T+5min: Analysis detects error rate 8% (threshold: <5%)
    ↓
Rollout PAUSES immediately
    ↓
Argo Rollouts triggers ROLLBACK
    ↓
Traffic shifts: 100% back to stable version
    ↓
Canary pods scaled down and deleted
    ↓
Slack alert sent: "⚠️ Rollout failed for gridos-dev"
    ↓
Deployment reverted, zero downtime achieved
```

**Why Argo Rollouts:**
- **Minimizes blast radius:** Only 20% of users see new version initially
- **Automated safety:** Metrics-based decisions, no human needed
- **Zero downtime:** Always keeps some stable pods running
- **Fast rollback:** Seconds to revert if issues detected
- **Confidence:** Gradual rollout reduces risk

**Output:** New version fully deployed or rolled back automatically

---

#### **STAGE 6: Post-Deployment Validation**

**GitHub Actions monitors deployment:**

**Job 3: Wait for Argo CD Sync (~3-10 minutes)**
- Polls Argo CD API: `argocd app get gridos-dev`
- Checks status: Syncing → Synced → Healthy
- Timeout: 10 minutes
- **Why:** Ensures Argo CD successfully applied manifests

**Job 4: Monitor Rollout Progress (~20 minutes)**
- Connects to AKS cluster
- Runs: `kubectl argo rollouts status gridos -n gridos --watch`
- Tracks canary progression: 20% → 40% → 60% → 80% → 100%
- Shows real-time rollout status
- **Why:** Visibility into progressive deployment, catches issues

**Job 5: Smoke Tests (~2 minutes)**
- Curls application endpoints:
  ```bash
  curl https://gridos-dev.example.com/health  # Health check
  curl https://gridos-dev.example.com/api/v1/scada/status  # SCADA status
  curl https://gridos-dev.example.com/metrics  # Prometheus metrics
  ```
- Retries 5 times with 10s delay (wait for DNS propagation)
- Fails pipeline if endpoints unreachable
- **Why:** Basic validation that app is accessible

**Job 6: Integration Tests (~5 minutes)**
- Runs real API tests against deployed environment:
  ```javascript
  // Test SCADA data ingestion
  POST /api/v1/scada/data 
  { "device_id": "test-device", "voltage": 230, "current": 10 }
  
  // Verify data retrieval
  GET /api/v1/scada/data?device_id=test-device
  
  // Test database connectivity
  GET /api/v1/health/db → { "status": "healthy" }
  
  // Verify metrics endpoint
  GET /metrics → Contains "http_requests_total"
  ```
- Full end-to-end validation
- Tests SCADA-specific functionality
- **Why:** Ensures app actually works, not just deployed

**Job 7: Slack Notification**
- Sends message:
  ```
  ✅ GridOS Deployment Successful
  Environment: dev
  Image: gridosacr.azurecr.io/gridos:test-a1b2c3d
  Commit: a1b2c3d
  Duration: 23 minutes
  ```
- **Why:** Team visibility, instant feedback

**Output:** Full deployment validated, team notified

---

#### **STAGE 7: Production Deployment (Main Branch)**

**When feature tested and ready:**

1. **Create Pull Request**
   ```bash
   git checkout main
   git merge feature/alarm-threshold-update
   git push
   ```

2. **Manual Approval Gate** (GitHub Environment Protection)
   - PR requires 2+ reviewer approvals
   - GitHub Environment "production" requires manual approval
   - Designated approvers receive notification
   - Approvers review:
     - Code changes
     - Test results
     - Security scan results
     - Dev environment performance
   - Click "Approve and deploy" button

3. **Same Pipeline Runs**
   - Build, test, scan (identical to dev)
   - Image tagged: `v123` (production versioning)
   - Manifest updated in `overlays/prod/`
   - Argo CD syncs to **production AKS cluster**
   - Canary deployment in production
   - Smoke + integration tests on production endpoints

4. **Success**
   - Production running new version
   - Zero downtime achieved
   - Metrics monitored in Grafana
   - On-call engineers alerted

**Production Safety Net:**
- Manual approval required
- Canary deployment (even in prod)
- Automatic rollback if metrics fail
- Tested in dev first

---

### Tools Summary (What Each Does)

| Tool | Purpose | What It Does in CI/CD |
|------|---------|------------------------|
| **GitHub Actions** | CI/CD orchestration | Triggers on code push, runs jobs (build, test, scan), updates Git |
| **Docker** | Containerization | Packages app + dependencies into portable image |
| **npm audit** | Dependency scanning | Checks package.json for known vulnerabilities in libraries |
| **Snyk** | Advanced dependency scan | Deeper vulnerability analysis with proprietary database |
| **Jest** | Testing framework | Runs unit tests, calculates code coverage |
| **Codecov** | Coverage tracking | Tracks code coverage trends over time, PRs show coverage diff |
| **Trivy** | Container security | Scans Docker images for OS and app vulnerabilities |
| **ESLint** | Code quality | Lints JavaScript, enforces style, detects bugs |
| **Azure Container Registry** | Image storage | Private Docker registry, securely stores built images |
| **Kustomize** | Config management | Merges base manifests + environment overlays → final YAML |
| **Argo CD** | GitOps deployment | Monitors Git, syncs Kubernetes cluster to match Git state |
| **Argo Rollouts** | Progressive delivery | Manages canary deployments, runs analysis, handles rollback |
| **Kubernetes (AKS)** | Container orchestration | Runs containerized apps, manages scaling, networking, health |
| **Istio** | Service mesh | Routes traffic for canary deployment (80% stable, 20% canary) |
| **Prometheus** | Metrics collection | Collects app metrics (success rate, latency) for analysis |
| **PostgreSQL** | Database | Stores SCADA time-series data (sensor readings, alarms) |
| **Application Gateway** | Ingress / WAF | Routes external traffic to AKS, provides Web Application Firewall |
| **Slack** | Notifications | Alerts team on deployment success/failure |

---

### Why This Workflow Is Production-Grade

✅ **Automated Safety:** 8 quality gates before production  
✅ **Progressive Rollout:** Canary deployment minimizes risk  
✅ **Automatic Rollback:** Metrics-based decisions, no human delay  
✅ **Zero Downtime:** Always keep stable version running  
✅ **Full Audit Trail:** Every deployment traceable via Git commits  
✅ **Fast Feedback:** Developers see results in minutes  
✅ **Security First:** Dependency + container scanning before deployment  
✅ **Real Testing:** Integration tests validate actual functionality  
✅ **Self-Healing:** Argo CD reverts manual changes automatically  
✅ **Scalable:** Same workflow for 1 app or 100 apps  

---

**This is production-ready, interview-winning infrastructure! 🚀**
