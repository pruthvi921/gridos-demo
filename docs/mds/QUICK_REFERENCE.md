# GitOps Quick Reference - GridOS on GitHub + Argo CD

## 📋 Daily Workflow

### Deploy New Version

```bash
# 1. Make code changes
vi src/app.js

# 2. Commit and push
git add .
git commit -m "feat: add SCADA voltage monitoring"
git push origin develop

# 3. Watch GitHub Actions (automatic)
# Visit: https://github.com/YOUR_ORG/sharedinfra/actions

# 4. Monitor Argo CD sync (automatic)
argocd app get gridos-dev --refresh

# 5. Watch rollout progress
kubectl argo rollouts get rollout gridos -n gridos --watch

# Done! ✅
```

### Rollback

```bash
# Option 1: Git revert (recommended)
git revert HEAD
git push origin develop
# Argo CD auto-syncs old version

# Option 2: Argo Rollouts undo
kubectl argo rollouts undo gridos -n gridos

# Option 3: Argo CD rollback
argocd app rollback gridos-dev <revision>
```

### Check Status

```bash
# Application sync status
argocd app list
argocd app get gridos-dev

# Rollout status
kubectl argo rollouts status gridos -n gridos
kubectl argo rollouts get rollout gridos -n gridos

# Canary analysis
kubectl get analysisrun -n gridos
kubectl describe analysisrun <name> -n gridos

# Pod status
kubectl get pods -n gridos -l app=gridos
```

## 🎯 Key URLs

- **GitHub Repo**: https://github.com/YOUR_ORG/sharedinfra
- **GitHub Actions**: https://github.com/YOUR_ORG/sharedinfra/actions
- **Argo CD UI**: https://argocd.gridos.example.com
- **Argo Rollouts Dashboard**: https://rollouts.gridos.example.com
- **GridOS Dev**: https://gridos-dev.example.com
- **GridOS Test**: https://gridos-test.example.com
- **GridOS Prod**: https://gridos.example.com

## 🔑 Key Concepts

### Git = Source of Truth
- All configuration in Git
- Cluster state matches Git
- Manual changes auto-reverted

### Argo CD = Deployment Engine
- Watches Git every 3 minutes
- Applies changes to cluster
- Keeps cluster in sync with Git

### Argo Rollouts = Canary Controller
- Manages progressive delivery
- Monitors Prometheus metrics
- Auto-rolls back on failures

### Application Gateway = Traffic Router
- AGIC watches Kubernetes Ingress
- Configures App Gateway automatically
- Routes traffic based on weights

## 🚨 Emergency Procedures

### Immediate Rollback
```bash
# Fastest: Abort current rollout
kubectl argo rollouts abort gridos -n gridos

# This keeps current stable version running
# Canary traffic goes to 0%
```

### Manual Hotfix
```bash
# In PROD only (selfHeal: false)
kubectl edit deployment gridos -n gridos

# Change persists until next Git sync
# Document in incident report
```

### Disable Auto-Sync
```bash
# Emergency: stop all deployments
argocd app set gridos-prod --sync-policy none

# Re-enable later
argocd app set gridos-prod --sync-policy automated
```

## 📊 Monitoring

### Argo CD Health
```bash
kubectl get pods -n argocd
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server
```

### Argo Rollouts Health
```bash
kubectl get pods -n argo-rollouts
kubectl logs -n argo-rollouts -l app.kubernetes.io/name=argo-rollouts
```

### Application Health
```bash
# Overall status
kubectl get rollout,pod,svc,ingress -n gridos

# Detailed rollout info
kubectl argo rollouts get rollout gridos -n gridos

# Analysis results
kubectl get analysisrun -n gridos --sort-by=.metadata.creationTimestamp
```

## 🔧 Troubleshooting

### "Argo CD shows OutOfSync"
```bash
# Check difference
argocd app diff gridos-dev

# Manual sync
argocd app sync gridos-dev

# Force sync (ignore hooks)
argocd app sync gridos-dev --force
```

### "Rollout is stuck"
```bash
# Check rollout status
kubectl argo rollouts get rollout gridos -n gridos

# Check analysis
kubectl get analysisrun -n gridos
kubectl describe analysisrun <name> -n gridos

# Manually promote (if safe)
kubectl argo rollouts promote gridos -n gridos

# Or abort and investigate
kubectl argo rollouts abort gridos -n gridos
```

### "GitHub Actions failed"
```bash
# Check workflow run in GitHub UI
# Re-run failed jobs
# Check secrets are configured
```

### "Image not updating"
```bash
# Check if CI updated manifest
git log applications/gridos/overlays/dev/kustomization.yaml

# Check Argo CD picked up change
argocd app get gridos-dev --refresh

# Manual sync
argocd app sync gridos-dev
```

## 📝 Cheat Sheet

| Task | Command |
|------|---------|
| List apps | `argocd app list` |
| App status | `argocd app get gridos-dev` |
| Manual sync | `argocd app sync gridos-dev` |
| Rollout status | `kubectl argo rollouts status gridos -n gridos` |
| Watch rollout | `kubectl argo rollouts get rollout gridos -n gridos --watch` |
| Promote canary | `kubectl argo rollouts promote gridos -n gridos` |
| Abort rollout | `kubectl argo rollouts abort gridos -n gridos` |
| Rollback | `kubectl argo rollouts undo gridos -n gridos` |
| Analysis runs | `kubectl get analysisrun -n gridos` |
| Pods | `kubectl get pods -n gridos -l app=gridos` |
| Logs | `kubectl logs -n gridos -l app=gridos --tail=100` |
| Dashboard | `kubectl argo rollouts dashboard` |

## 🎓 For Interview

**Key points to mention:**

1. **GitOps = Git as single source of truth**
   - All config in Git
   - Argo CD pulls from Git
   - Drift automatically corrected

2. **Canary Deployment = Progressive traffic shift**
   - 10% → 25% → 50% → 100%
   - Prometheus metrics validation
   - Auto-rollback in 90 seconds

3. **Separation of Concerns**
   - GitHub Actions = CI (build, test)
   - Argo CD = CD (deploy, sync)
   - Argo Rollouts = Progressive delivery
   - Application Gateway = Traffic routing

4. **Production Safety**
   - Manual approval required
   - Slower canary (19 min total)
   - Sync windows (no deploy during peak)
   - Multiple rollback options

5. **Compliance Ready**
   - Immutable Git history
   - Every change auditable
   - NERC CIP compliant
   - Disaster recovery = Git clone

**Practice saying:**
> "I implemented a GitOps architecture using Argo CD for continuous deployment and Argo Rollouts for progressive delivery. The system automatically deploys changes from Git to Kubernetes with metric-based canary deployments and automatic rollback. For a power grid monitoring system, this provides the audit trail and reliability required for NERC CIP compliance while enabling rapid, safe deployments."

---

**You're ready for the GE interview! 🚀**
