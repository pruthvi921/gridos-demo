# Git Branching Strategy

## Overview

This project follows a **Feature Branch + Develop + Main** branching strategy with automated CI/CD pipelines.

```
feature/* ────┐
              ├──→ develop ────→ main/master ────→ Production
feature/* ────┘       ↓                ↓
                     DEV             PROD
                (Auto-deploy)    (With Approval)
```

---

## Branch Structure

### 1. **Main / Master** (Protected)
- **Purpose:** Production-ready code
- **Protection:** 
  - ✅ Requires PR approval (2+ reviewers)
  - ✅ Status checks must pass
  - ✅ No direct commits
- **Deploys to:** Production
- **Deployment:** Automatic after approval

### 2. **Develop** (Semi-Protected)
- **Purpose:** Integration branch for features
- **Protection:**
  - ✅ Requires PR approval (1+ reviewer)
  - ✅ Status checks must pass
- **Deploys to:** Dev environment
- **Deployment:** Automatic on every push

### 3. **Feature Branches** (feature/*)
- **Purpose:** New features, bug fixes, improvements
- **Naming:** `feature/<ticket-id>-<description>`
- **Examples:**
  - `feature/GE-123-add-metrics`
  - `feature/GE-456-fix-memory-leak`
  - `feature/refactor-networking`
- **Deploys to:** Dev environment
- **Deployment:** Automatic on every push
- **Lifetime:** Deleted after merge

---

## Workflow

### Creating a New Feature

```bash
# 1. Start from latest develop
git checkout develop
git pull origin develop

# 2. Create feature branch
git checkout -b feature/GE-123-add-metrics

# 3. Make changes and commit regularly
git add .
git commit -m "feat: add Prometheus metrics endpoint"
git push origin feature/GE-123-add-metrics

# Result: CI runs tests + Auto-deploys to DEV
```

### Regular Commits to Feature Branch

```bash
# Make changes
git add src/metrics.py
git commit -m "feat: add CPU metrics collection"
git push origin feature/GE-123-add-metrics

# Every push triggers:
# - CI: Build → Test → Push to ACR
# - CD: Update manifests → Argo CD syncs → Deploy to DEV
```

### Merging Feature to Develop

```bash
# 1. Create Pull Request (via GitHub UI)
#    feature/GE-123-add-metrics → develop

# 2. PR triggers:
#    - All tests run
#    - Code review required
#    - Status checks must pass

# 3. After approval, merge PR

# 4. Develop branch updated → Auto-deploy to DEV
```

### Deploying to Production

```bash
# 1. Create Pull Request (via GitHub UI)
#    develop → main

# 2. PR triggers:
#    - Infrastructure tests
#    - Application tests
#    - Security scans
#    - 2+ reviewers required

# 3. After approval, merge PR

# 4. Main branch updated triggers:
#    - Infrastructure deployment (with approval)
#    - Application deployment (Argo CD syncs prod)
```

---

## Pipeline Behavior

### Feature Branch Push (`feature/*`)

```
Push to feature/my-feature
    ↓
┌─────────────────────────────────┐
│ Application CI/CD               │
│ 1. Build & Test                 │
│ 2. Push to ACR                  │
│ 3. Update manifest (dev)        │
│ 4. Argo CD syncs → Deploy DEV   │
└─────────────────────────────────┘
    +
┌─────────────────────────────────┐
│ Infrastructure (if terraform/)  │
│ 1. Run tests                    │
│ 2. Deploy to DEV                │
└─────────────────────────────────┘
    ↓
✅ Changes live in DEV environment
```

### Develop Branch Push

```
Merge PR → develop updated
    ↓
┌─────────────────────────────────┐
│ Application CI/CD               │
│ 1. Build & Test                 │
│ 2. Push to ACR                  │
│ 3. Update manifest (dev)        │
│ 4. Argo CD syncs → Deploy DEV   │
└─────────────────────────────────┘
    +
┌─────────────────────────────────┐
│ Infrastructure (if terraform/)  │
│ 1. Run tests                    │
│ 2. Deploy to DEV                │
└─────────────────────────────────┘
    ↓
✅ Integrated changes live in DEV
```

### Main/Master Branch Push

```
Merge PR → main updated
    ↓
┌─────────────────────────────────┐
│ Application CI/CD               │
│ 1. Build & Test                 │
│ 2. Push to ACR                  │
│ 3. Update manifest (prod)       │
│ 4. Argo CD waits (manual sync)  │
└─────────────────────────────────┘
    +
┌─────────────────────────────────┐
│ Infrastructure (if terraform/)  │
│ 1. Run tests                    │
│ 2. ⏸️  WAIT for approval        │
│ 3. Deploy to PROD               │
└─────────────────────────────────┘
    ↓
⏸️  Manual approval required
    ↓ (Approve in GitHub)
✅ Changes deployed to PRODUCTION
```

### Pull Request (Any → main/develop)

```
Open PR
    ↓
┌─────────────────────────────────┐
│ Tests Only (No Deployment)      │
│ ✅ Infrastructure tests         │
│ ✅ Application tests            │
│ ✅ Security scans               │
│ ✅ Format/Lint checks           │
└─────────────────────────────────┘
    ↓
Results posted as PR comment
    ↓
✅ Approve → Allow merge
❌ Fail → Request changes
```

---

## Deployment Matrix

| Branch | Application Deployment | Infrastructure Deployment | Approval Required |
|--------|----------------------|--------------------------|-------------------|
| `feature/*` | ✅ Auto → DEV | ✅ Auto → DEV | ❌ No |
| `develop` | ✅ Auto → DEV | ✅ Auto → DEV | ❌ No |
| `main/master` | ✅ Auto → PROD (Argo waits) | ⏸️ Manual → PROD | ✅ Yes (2+) |
| `PR to develop` | ❌ Tests only | ❌ Tests only | ✅ Yes (1+) |
| `PR to main` | ❌ Tests only | ❌ Tests only | ✅ Yes (2+) |

---

## Branch Protection Rules

### Main/Master Branch

**Settings → Branches → Add rule → `main`**

- ✅ **Require pull request before merging**
  - Required approvals: **2**
  - Dismiss stale reviews: Yes
- ✅ **Require status checks to pass**
  - `Infrastructure Tests`
  - `Build and Test`
  - `Security Scan`
- ✅ **Require conversation resolution**
- ✅ **Require linear history**
- ✅ **Include administrators** (recommended)
- ✅ **Restrict who can push** (Only via PR)

### Develop Branch

**Settings → Branches → Add rule → `develop`**

- ✅ **Require pull request before merging**
  - Required approvals: **1**
- ✅ **Require status checks to pass**
  - `Infrastructure Tests`
  - `Build and Test`
- ✅ **Require conversation resolution**
- ❌ Include administrators (allow admin push for hotfixes)

### Feature Branches

**No protection needed** - Short-lived, deleted after merge

---

## Commit Message Convention

Follow **Conventional Commits** for clear history:

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

### Types
- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation changes
- `style:` Code style (formatting, missing semicolons)
- `refactor:` Code refactoring
- `test:` Adding/updating tests
- `chore:` Maintenance tasks
- `perf:` Performance improvements
- `ci:` CI/CD changes

### Examples
```bash
git commit -m "feat(metrics): add Prometheus metrics endpoint"
git commit -m "fix(networking): resolve memory leak in connection pool"
git commit -m "docs(readme): update deployment instructions"
git commit -m "ci(pipeline): add infrastructure tests"
```

---

## Common Scenarios

### Scenario 1: Working on a Feature

```bash
# Create branch
git checkout -b feature/GE-789-improve-logging

# Make changes and test locally
# ... code changes ...

# Commit and push (triggers CI/CD to DEV)
git add .
git commit -m "feat(logging): add structured logging with context"
git push origin feature/GE-789-improve-logging

# Continue working, push regularly
# ... more changes ...
git commit -m "test(logging): add unit tests for logger"
git push

# When ready, create PR to develop
# GitHub UI: feature/GE-789-improve-logging → develop
```

### Scenario 2: Hotfix in Production

```bash
# Create hotfix branch from main
git checkout main
git pull origin main
git checkout -b hotfix/critical-security-patch

# Make fix
# ... fix the issue ...

# Commit and push
git commit -m "fix(security): patch CVE-2024-XXXX vulnerability"
git push origin hotfix/critical-security-patch

# Create PR to main (requires 2+ approvals)
# After approval, merge

# Also merge back to develop
git checkout develop
git merge hotfix/critical-security-patch
git push origin develop
```

### Scenario 3: Release to Production

```bash
# Ensure develop is tested and stable
# Review all changes since last release

# Create PR: develop → main
# Title: "Release v1.2.0"
# Description: List of features/fixes

# Wait for approvals (2+ required)
# Merge PR

# Monitor deployment:
# 1. Infrastructure tests run
# 2. Infrastructure approval required → Approve
# 3. Infrastructure deployed to prod
# 4. Application manifests updated
# 5. Argo CD shows "OutOfSync" for prod
# 6. Manually sync in Argo CD UI
# 7. Rollout proceeds with canary strategy
```

---

## Best Practices

### ✅ DO

1. **Branch from develop** for new features
2. **Push frequently** to feature branches (backup + CI feedback)
3. **Keep PRs small** (<500 lines if possible)
4. **Write descriptive commits** following conventions
5. **Delete feature branches** after merge
6. **Review PR comments** and respond promptly
7. **Test locally** before pushing
8. **Update documentation** with code changes

### ❌ DON'T

1. **Don't commit directly** to main/develop
2. **Don't push untested code** to develop
3. **Don't create long-lived** feature branches (>1 week)
4. **Don't merge without** status checks passing
5. **Don't ignore** failed CI/CD runs
6. **Don't skip** code reviews
7. **Don't commit secrets** or credentials
8. **Don't force push** to shared branches

---

## Git Workflow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                       Repository                             │
│                                                              │
│  feature/GE-123  ─┐                                         │
│                    ├──→ develop ──→ main/master             │
│  feature/GE-456  ─┘       │             │                   │
│                            ↓             ↓                   │
│                          DEV          PROD                   │
│                    (Auto-deploy)  (Manual approve)           │
└─────────────────────────────────────────────────────────────┘
```

---

## Troubleshooting

### Pipeline Fails on Feature Branch

**Issue:** CI/CD fails when pushing to feature branch

**Solution:**
```bash
# Check the logs in GitHub Actions
# Fix the issues locally
git add .
git commit -m "fix: resolve CI issues"
git push origin feature/my-feature

# Pipeline retries automatically
```

### Can't Merge PR - Status Checks Failing

**Issue:** PR blocked due to failed status checks

**Solution:**
1. Review failed checks in PR
2. Fix issues in feature branch
3. Push fixes
4. Wait for checks to pass
5. Request re-review if needed

### Accidentally Committed to Develop

**Issue:** Pushed directly to develop instead of feature branch

**Solution:**
```bash
# Revert the commit
git revert <commit-hash>
git push origin develop

# Create proper feature branch
git checkout -b feature/my-changes <commit-hash>
git push origin feature/my-changes

# Create PR: feature/my-changes → develop
```

---

## Interview Talking Points

> **"We follow a GitOps branching strategy with three tiers:**
> 
> **Feature branches** - Developers create `feature/*` branches for new work. Every push triggers CI that builds, tests, and auto-deploys to our dev environment. This gives fast feedback loops - developers see their changes running in Kubernetes within 5-10 minutes.
> 
> **Develop branch** - Acts as our integration branch. Features are merged here via PR after code review. It stays in sync with our dev environment, so QA always tests the latest integrated code.
> 
> **Main/Master** - Production-ready code only. Merges require 2+ approvals and all status checks passing. When merged, infrastructure changes require manual approval before deploying to prod. Application changes update the prod manifests, but Argo CD waits for manual sync - giving us control over production releases.
> 
> This strategy gives us continuous deployment to dev for rapid iteration, while maintaining strict controls for production. The branch structure maps directly to our environments, making it intuitive for the team."

---

## Related Documentation

- [Pipeline Architecture](PIPELINE_ARCHITECTURE.md) - How pipelines work
- [Infrastructure Pipeline Setup](INFRA_PIPELINE_SETUP.md) - Deployment automation
- [GitOps Best Practices](../GITOPS_BEST_PRACTICES.md) - GitOps patterns
