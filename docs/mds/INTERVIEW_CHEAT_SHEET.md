# CI/CD Quick Reference - Interview Cheat Sheet

## 30-Second Elevator Pitch

*"I built a production-grade GitOps CI/CD pipeline for a SCADA monitoring system using GitHub Actions for CI, Argo CD for continuous deployment, and Argo Rollouts for canary deployments. Terraform provisions Azure infrastructure, Helm bootstraps GitOps tools, and Kustomize manages environment-specific configs. The pipeline includes multi-layer security scanning, 70% code coverage enforcement, automated integration tests, and progressive delivery with automatic rollback capabilities."*

---

## The Flow in 10 Steps

1. **Developer pushes code** → GitHub Actions triggers
2. **Build & scan** → Docker image + security/quality checks
3. **Tests pass** → Image pushed to Azure Container Registry
4. **GitOps commit** → CI updates Kustomize manifest with new image tag
5. **Argo CD detects** → Git change detected (polls every 3 min)
6. **Argo CD syncs** → Applies manifests to Kubernetes
7. **Canary begins** → 20% → 40% → 60% → 80% → 100% traffic
8. **Analysis runs** → Success/error rates checked at each step
9. **Validation** → Smoke tests + integration tests run
10. **Success** → Slack notification sent ✅

**If failure at any step:** Automatic rollback + alert

---

## Key Technologies (What & Why)

| Technology | Purpose | Why This Choice |
|------------|---------|-----------------|
| **GitHub Actions** | CI orchestration | Native GitHub integration, easy workflows |
| **Terraform** | Infrastructure as Code | Declarative, cloud-agnostic, state management |
| **Argo CD** | GitOps deployment | Declarative K8s deployments, self-healing |
| **Argo Rollouts** | Progressive delivery | Canary deployments, automated rollback |
| **Helm** | Bootstrap tooling | Simplifies complex app installation |
| **Kustomize** | Config management | Template-free, patch-based, K8s-native |
| **Docker** | Containerization | Standard, portable, efficient |
| **Azure AKS** | Kubernetes platform | Managed K8s, Azure integration |
| **Trivy** | Container scanning | Fast, accurate, free |
| **Snyk** | Dependency scanning | Deep analysis, database of vulns |

---

## Architecture in ASCII

```
Developer → GitHub → CI (Build/Test/Scan) → ACR → Git Update
                                                        ↓
                                                    Argo CD
                                                        ↓
                                              Argo Rollouts (Canary)
                                                        ↓
                                                  AKS Cluster
                                                        ↓
                                                   End Users
```

---

## Canary Deployment Timeline

```
Time    Canary%    Action
────────────────────────────────────────────
T+0     0%         Deployment starts
T+1     20%        Analysis #1 (pause 5min)
T+6     40%        Analysis #2 (pause 5min)
T+11    60%        Analysis #3 (pause 5min)
T+16    80%        Analysis #4 (pause 5min)
T+21    100%       Full promotion ✅

If ANY analysis fails → Automatic rollback to 100% stable
```

---

## Quality Gates Checklist

✅ **Dependency Scan** (npm audit + Snyk)  
✅ **Container Scan** (Trivy)  
✅ **Unit Tests** (Jest with 70% coverage)  
✅ **Code Quality** (ESLint)  
✅ **Smoke Tests** (health, status, metrics)  
✅ **Integration Tests** (full API validation)  
✅ **Canary Analysis** (success/error rates)  
✅ **Manual Approval** (production only)  

---

## Branching Strategy

```
feature/xyz → dev environment (auto-deploy, test-abc1234)
develop     → dev environment (auto-deploy, dev-abc1234)
main        → prod environment (manual approval, v123)
```

---

## Rollback Strategies

1. **Automatic** (fastest): Argo Rollouts detects analysis failure → rollback
2. **Git Revert**: `git revert abc123` → Argo CD syncs old version (~3min)
3. **Manual UI**: Click "Rollback" in Argo Rollouts dashboard
4. **Emergency**: Update Kustomize tag, commit, push

---

## GitOps Benefits (Talking Points)

✅ **Single Source of Truth**: Git has full deployment history  
✅ **Audit Trail**: Every change is a Git commit  
✅ **Self-Healing**: Argo CD detects + fixes drift  
✅ **Easy Rollback**: Just `git revert`  
✅ **Declarative**: Desired state vs imperative commands  
✅ **Security**: No cluster credentials in CI  

---

## Common Questions - Quick Answers

**Q: Why GitOps over push-based CD?**  
A: Declarative, auditable, self-healing, Git as single source of truth

**Q: How do canary deployments work?**  
A: Progressive traffic shift (20→40→60→80→100%) with analysis at each step

**Q: What if canary fails?**  
A: Automatic rollback to stable version, zero downtime

**Q: How do you handle secrets?**  
A: Azure Key Vault + Secrets Store CSI driver in Kubernetes

**Q: Database migrations?**  
A: Init containers with backward-compatible migrations

**Q: Why Kustomize over Helm for apps?**  
A: Simpler, template-free, better for environment patches

**Q: How do you test infra changes?**  
A: Terraform validate, TFLint, Checkov, plan review in CI

**Q: Zero downtime deployments?**  
A: Canary rollouts + health checks + automatic rollback

---

## File Structure (Where Things Live)

```
.github/workflows/        → CI/CD pipelines
terraform/environments/   → Infrastructure (dev/test/prod)
applications/gridos/      → Kubernetes manifests
  ├── base/              → Common configs
  └── overlays/          → Environment-specific
argocd/                  → Argo CD app definitions
scripts/                 → Bootstrap scripts
tests/integration/       → API integration tests
```

---

## Metrics & Monitoring

| What | Where | Why |
|------|-------|-----|
| App metrics | Prometheus | Performance monitoring |
| Dashboards | Grafana | Visualization |
| Logs | Azure Log Analytics | Troubleshooting |
| Alerts | Slack | Real-time notifications |
| Vulnerabilities | GitHub Security | Security tracking |
| Coverage | Codecov | Quality tracking |
| Sync status | Argo CD UI | Deployment status |
| Rollout progress | Argo Rollouts UI | Canary monitoring |

---

## Security Layers

1. **Dependency Scanning**: npm audit + Snyk (before build)
2. **Container Scanning**: Trivy (after build)
3. **Network Security**: Azure NSGs + Application Gateway WAF
4. **Secrets Management**: Azure Key Vault
5. **RBAC**: Kubernetes role-based access control
6. **Pod Security**: Security contexts, non-root users
7. **Image Security**: ACR private registry, image signing

---

## Production Deployment Checklist

1. ✅ Feature tested in dev
2. ✅ All tests passing
3. ✅ Security scans clean
4. ✅ PR reviewed and approved
5. ✅ Merged to main
6. ✅ CI pipeline passes
7. ✅ Manual approval obtained (2+ approvers)
8. ✅ GitOps commit created
9. ✅ Argo CD syncs to prod
10. ✅ Canary deployment progresses
11. ✅ All analysis passes
12. ✅ Smoke tests validate
13. ✅ Monitoring confirms health
14. ✅ Team notified ✅

---

## Key Numbers to Remember

- **3 environments**: dev, test, prod
- **1 application**: GridOS (SCADA monitoring)
- **70% code coverage** threshold
- **3 minute** Argo CD sync interval
- **5 minute** pause between canary steps
- **5 canary phases**: 20%, 40%, 60%, 80%, 100%
- **20 minute** rollout timeout
- **10 minute** Argo CD sync timeout
- **2+ approvers** for production
- **3 workflows**: ci-cd, infra-deploy, infra-test

---

## Technology Versions

- Terraform: 1.6.0+
- Kubernetes: 1.28+
- Argo CD: 5.51.6
- Argo Rollouts: 2.34.3
- Node.js: 18
- Azure provider: 3.80+

---

## Demo Script (5 minutes)

1. **Show GitHub Actions** (30s)
   - "Here's our ci-cd.yml with 8 jobs"
   - "Quality gates: dependency scan, tests, security"

2. **Show Kustomize Structure** (30s)
   - "Base manifests + overlays for environments"
   - "CI updates image tag in overlay"

3. **Show Argo CD Dashboard** (1m)
   - "Monitors Git, shows sync status"
   - "Self-healing enabled, auto-sync"

4. **Show Argo Rollouts** (1m)
   - "Canary strategy with 5 phases"
   - "Automated analysis at each step"
   - "Automatic rollback on failure"

5. **Show Rollout Manifest** (1m)
   - "20% canary, 5min pause, analysis"
   - "Success rate and error rate checks"

6. **Show Terraform** (30s)
   - "Infrastructure as code for AKS, PostgreSQL"
   - "Separate pipeline with approval gates"

7. **Walk Through Deployment** (1m)
   - "Code commit → CI → GitOps commit → Argo CD → Canary → Tests → Success"
   - "If any step fails, automatic rollback"

---

## Whiteboard Practice

Draw this on a whiteboard:

```
┌────────┐    ┌────────┐    ┌────────┐    ┌────────┐
│Developer│ → │GitHub  │ → │ Argo   │ → │  AKS   │
│  Code  │    │Actions │    │  CD    │    │Cluster │
└────────┘    └────────┘    └────────┘    └────────┘
                  ↓             ↑              ↓
              [Build]       [GitOps]      [Canary]
              [Test]        [Monitor]     [Analysis]
              [Scan]        [Sync]        [Rollback]
                  ↓             ↑
              [Git Update] ─────┘
```

---

## Confidence Boosters

You have implemented:
✅ Enterprise-grade CI/CD  
✅ GitOps best practices  
✅ Progressive delivery  
✅ Multi-layer security  
✅ Comprehensive testing  
✅ Infrastructure as Code  
✅ Self-healing deployments  
✅ Zero-downtime releases  

**You've built production infrastructure for a Fortune 500 company (GE)!**

---

## Last-Minute Tips

1. **Be specific**: Use actual file names and tools
2. **Show enthusiasm**: Talk about why you chose each technology
3. **Admit unknowns**: "I haven't implemented X yet, but here's how I would..."
4. **Draw diagrams**: Visual explanations are powerful
5. **Tell stories**: "When we had this issue, here's how the pipeline caught it..."
6. **Know your numbers**: Coverage %, deployment time, rollback speed
7. **Security focus**: Mention scanning at every answer opportunity
8. **GitOps benefits**: Emphasize declarative, auditable, self-healing

---

## Emergency: Forgot Something?

**Remember the acronym: B.A.C.K.U.P.**

- **B**uild: Docker image creation
- **A**nalyze: Security scans + tests
- **C**ommit: GitOps manifest update
- **K**ubernetes: Argo CD applies to cluster
- **U**pgrade: Canary progressive delivery
- **P**rove: Validation tests confirm success

---

**Print this. Keep it handy. You got this! 🚀**
