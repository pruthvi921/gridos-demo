# GridOS Platform - Production-Ready GitOps Infrastructure

## 🎯 Overview
A **production-ready GitOps pipeline** for the GridOS platform, demonstrating enterprise-grade Site Reliability Engineering (SRE) practices with **complete automation** and **zero manual intervention**.

### What Makes This Special

✅ **Fully Automated** - Single command deploys entire infrastructure + GitOps stack  
✅ **GitOps Methodology** - Git as single source of truth, pull-based deployment  
✅ **Progressive Delivery** - Canary deployments with automated Prometheus analysis  
✅ **Zero Manual Commands** - No kubectl/helm commands needed after initial setup  
✅ **Production-Ready** - High availability, security, observability built-in  
✅ **Interview-Ready** - Complete documentation + working demo  

### Technology Stack

| Layer | Technology | Purpose |
|-------|-----------|---------|
| **Version Control** | GitHub | Single source of truth |
| **CI Pipeline** | GitHub Actions | Build, test, push to ACR |
| **CD Pipeline** | Argo CD | GitOps-based deployment |
| **Progressive Delivery** | Argo Rollouts | Canary with automated analysis |
| **Infrastructure** | Terraform + Helm | IaC for Azure + GitOps tools |
| **Container Registry** | Azure Container Registry | Private Docker images |
| **Kubernetes** | Azure Kubernetes Service | Container orchestration |
| **Ingress** | Application Gateway + AGIC | Traffic routing, SSL |
| **Config Management** | Kustomize | Environment-specific overlays |
| **Metrics** | Prometheus | Analysis + monitoring |
| **Observability** | Application Insights | Logs, metrics, traces |

---


### 

**⚡ Fully automated infrastructure deployment with approval gates!**

infrastructure is fully automated using Terraform with a modular, reusable approach across dev, test, and production environments.

designed a modular Terraform setup to ensure reusability, consistency, and environment isolation.

terraform/
├── modules/                    # Reusable components
│   ├── networking/            # VNet, Subnets, NSG, Private Endpoints
│   ├── kubernetes/            # AKS cluster, node pools, RBAC
│   ├── database/              # PostgreSQL Flexible Server
│   ├── app-gateway/           # Application Gateway + WAF
│   ├── acr/                   # Azure Container Registry
│   ├── key-vault/             # Key Vault + access policies
│   ├── observability/         # Log Analytics, App Insights
│   └── storage/               # Storage accounts for state/data
│
└── environments/              # Environment-specific configs
    ├── dev/
    │   ├── main.tf            # Orchestrates modules
    │   ├── variables.tf       # Input parameters
    │   ├── terraform.tfvars   # Dev-specific values
    │   ├── outputs.tf         # Outputs for other tools
    │   └── backend.tf         # Remote state in Azure Storage
    ├── test/
    └── prod/

**Features:**
- ✅ Auto-deploy dev on push to main
- ✅ Manual approval gates for test/prod
- ✅ Automatic GitOps bootstrap after infrastructure
- ✅ Plan-only mode for safe reviews
- ✅ State management in Azure Storage

**Trigger deployment:**
```bash
# Push terraform changes → auto-deploys dev
git add terraform/
git commit -m "Update infrastructure"
git push origin main

# Or use GitHub UI: Actions → Infrastructure Deployment → Run workflow
```





## 🏗️ Architecture

### GitOps Flow
The system automatically deploys changes from Git to Kubernetes with metric-based canary deployments and automatic rollback

```
Developer
    ↓ git push
GitHub Repository (Source of Truth)
    ↓ webhook
GitHub Actions (CI)
    - Build Docker image
    - Run tests
    - Push to Azure Container Registry
    - Update Kustomize image tag
    ↓ commit
GitHub Repository (Updated manifests)
    ↓ poll every 3min
Argo CD (GitOps CD)
    - Detect drift
    - Auto-sync cluster
    ↓ kubectl apply -k
Argo Rollouts (Progressive Delivery)
    - Canary: 10% → 25% → 50% → 100%
    - Prometheus analysis at each step
    - Automatic rollback on failure
    ↓
Azure Kubernetes Service
    - Application Gateway ingress
    - HPA (2-10 pods)
    - Full observability
```


## 🔄 How It Works

### Example: Deploying a New Feature

1. **Developer makes change:**
   ```bash
   # Edit code, commit, push
   git commit -m "Add new feature"
   git push origin main
   ```

2. **GitHub Actions (CI) runs automatically:**
   - Builds Docker image: `gridos-app:v1.0.1`
   - Runs unit tests + integration tests
   - Scans for vulnerabilities
   - Pushes to Azure Container Registry
   - Updates `applications/gridos/overlays/dev/kustomization.yaml`:
     ```yaml
     images:
       - name: gridosacr.azurecr.io/gridos-app
         newTag: v1.0.1  # ← Updated by CI
     ```
   - Commits change back to Git

3. **Argo CD detects change (within 3 minutes):**
   - Polls GitHub every 3 minutes
   - Detects manifest change
   - Status: "OutOfSync"
   - Auto-syncs (applies new manifests to cluster)

4. **Argo Rollouts executes canary:**
   ```
   00:00 - Deploy canary pods (v1.0.1)
   00:01 - Route 10% traffic to canary
   00:01-00:31 - Prometheus analysis (30s)
           ✓ Success rate: 99.5% (>99% required)
           ✓ Latency p95: 420ms (<500ms required)
           ✓ Error rate: 0.2% (<1% required)
   00:31 - ✓ Pass → Promote to 25%
   00:31-01:01 - Analysis (30s)
   01:01 - ✓ Pass → Promote to 50%
   01:01-01:31 - Analysis (30s)
   01:31 - ✓ Pass → Promote to 100%
   01:32 - 🎉 Rollout complete!
   ```

5. **If any analysis fails:**
   - ❌ Automatic rollback to stable version
   - Canary pods terminated
   - 100% traffic to stable
   - GitHub status updated: "Deployment failed"
   - Zero downtime maintained


## ✅ Success Criteria

Deployment is successful when:

- ✅ Terraform apply completes without errors
- ✅ All AKS nodes are Ready
- ✅ Argo CD UI accessible
- ✅ Rollouts Dashboard accessible
- ✅ `gridos-dev` application shows "Synced" and "Healthy"
- ✅ Application pods running
- ✅ Git push triggers auto-sync
- ✅ Canary rollout completes successfully
- ✅ Rollback works instantly

---

## 🛠️ Troubleshooting

See [COMPLETE_DEPLOYMENT_GUIDE.md - Troubleshooting](COMPLETE_DEPLOYMENT_GUIDE.md#-troubleshooting) for detailed fixes.

**Quick fixes:**

```bash
# Argo CD not syncing
argocd app sync gridos-dev --hard-refresh

# Rollout stuck
kubectl argo rollouts promote gridos -n gridos-dev

# GitHub auth failed
kubectl create secret generic github-repo-secret \
  --from-literal=username=$GITHUB_USERNAME \
  --from-literal=password=$GITHUB_TOKEN \
  --namespace argocd --dry-run=client -o yaml | kubectl apply -f -
```

---

## 🚀 Next Steps

### For Production

1. Create prod overlay (5 replicas, slow canary)
2. Deploy Prometheus for metrics
3. Configure production domains + SSL
4. Enable Azure AD authentication
5. Set up alerting (PagerDuty/OpsGenie)

See [COMPLETE_DEPLOYMENT_GUIDE.md - Next Steps](COMPLETE_DEPLOYMENT_GUIDE.md#-next-steps) for details.

---

## 📞 Support

**Questions or issues?**

1. Check [COMPLETE_DEPLOYMENT_GUIDE.md](COMPLETE_DEPLOYMENT_GUIDE.md) - Troubleshooting section
2. Check [QUICK_REFERENCE.md](QUICK_REFERENCE.md) - Quick fixes
3. Review logs: `kubectl logs -n argocd` and `kubectl logs -n argo-rollouts`

---

## 🎉 What You Get

A **production-grade GitOps pipeline** featuring:

✅ Complete automation (zero manual commands)  
✅ GitOps methodology (Argo CD)  
✅ Progressive delivery (Argo Rollouts)  
✅ Multi-environment support  
✅ High availability  
✅ Security best practices  
✅ Full observability  
✅ Comprehensive documentation  
✅ Interview-ready demo  

**Perfect for demonstrating SRE expertise at companies like GE Grid Solutions!**

---

## 📄 License

This project is for demonstration purposes. Adapt as needed for your use case.

---

**Built with ❤️ for SRE excellence**
.
├── .github/
│   └── workflows/              # CI/CD pipeline definitions
│       ├── ci-pipeline.yml
│       ├── cd-dev.yml
│       ├── cd-test.yml
│       ├── cd-prod.yml
│       └── security-scan.yml
├── terraform/
│   ├── modules/               # Reusable infrastructure modules
│   │   ├── networking/
│   │   ├── kubernetes/
│   │   ├── database/
│   │   ├── monitoring/
│   │   └── security/
│   ├── environments/          # Environment-specific configurations
│   │   ├── dev/
│   │   ├── test/
│   │   └── prod/
│   └── backend.tf             # Remote state configuration
├── src/
│   ├── GridOS.API/            # REST API for grid monitoring
│   ├── GridOS.DataService/    # Data processing microservice
│   ├── GridOS.WebPortal/      # Frontend application
│   └── GridOS.Common/         # Shared libraries
├── kubernetes/
│   ├── helm-charts/           # Helm charts for deployments
│   │   └── gridos/
│   ├── base/                  # Base Kubernetes resources
│   └── overlays/              # Kustomize overlays per environment
├── monitoring/
│   ├── grafana/
│   │   ├── dashboards/        # Custom Grafana dashboards
│   │   └── datasources/
│   ├── prometheus/
│   │   ├── rules/             # Alert rules
│   │   └── config/
│   └── loki/
│       └── config/
├── scripts/
│   ├── incident-response/     # Automated incident runbooks
│   ├── capacity-planning/     # Capacity analysis scripts
│   └── deployment/            # Deployment automation
├── docs/
│   ├── runbooks/              # Operational runbooks
│   ├── postmortems/           # Incident postmortem templates
│   ├── sre-practices/         # SRE documentation
│   └── architecture/          # Architecture diagrams
└── tests/
    ├── unit/
    ├── integration/
    └── load/                  # Load testing scenarios
```

## 🏗️ Infrastructure as Code

### Terraform Modules

#### Networking Module
- VPC/VNet with public and private subnets
- NAT Gateway for outbound traffic
- Network Security Groups with least privilege
- Service endpoints for Azure services

#### Kubernetes Module
- AKS/EKS cluster with auto-scaling node pools
- RBAC configuration with Azure AD/AWS IAM integration
- Network policies for pod-to-pod communication
- Cluster autoscaler and metrics server

#### Database Module
- PostgreSQL Flexible Server with high availability
- Automated backups and point-in-time recovery
- Private endpoint connectivity
- Connection pooling with PgBouncer

#### Monitoring Module
- Prometheus with long-term storage
- Grafana with pre-configured dashboards
- Loki for centralized logging
- AlertManager with PagerDuty integration

### Environment Management

```bash
# Deploy to specific environment
cd terraform/environments/<dev|test|prod>
terraform workspace select <env>
terraform apply -var-file="terraform.tfvars"

# State management with remote backend (Azure Storage/S3)
```

## 🔄 CI/CD Pipeline

### Pipeline Stages

1. **Build & Test**
   - Restore dependencies
   - Compile application
   - Run unit tests with coverage
   - Build Docker images

2. **Security Scanning**
   - SAST with SonarQube
   - Container scanning with Trivy
   - Dependency vulnerability check (Snyk)
   - Secret detection with GitLeaks

3. **Integration Testing**
   - Deploy to ephemeral test environment
   - Run integration tests
   - Database migration tests
   - API contract testing

4. **Deployment**
   - Terraform infrastructure validation
   - Helm chart deployment
   - Blue-Green deployment strategy
   - Smoke tests post-deployment

5. **Verification**
   - Health check validation
   - SLO compliance check
   - Performance baseline comparison
   - Rollback on failure

### Deployment Strategy

- **Dev**: Automatic deployment on merge to `develop` branch
- **Test**: Automatic deployment with approval gate
- **Prod**: Manual approval with change management ticket



### Alert Rules

- **Critical**: Service unavailability, database connection failures
- **Warning**: High error rates, resource saturation, slow queries
- **Info**: Deployment events, configuration changes




