# Quick Reference: Infrastructure Pipelines

## Two Pipelines Working Together

### Pipeline 1: `infra-test.yml` (Tests Only)
**Purpose:** Validate infrastructure code quality and security
**Deployment:** ❌ No
**Runs On:**
- Every Pull Request
- Called by infra-deploy.yml
- Manual trigger

```
┌──────────────────────┐
│  infra-test.yml      │
│                      │
│  ✅ Format Check     │
│  ✅ TFLint          │
│  ✅ Checkov         │
│  ✅ Validate        │
│  ✅ Plan Dry Run    │
│  ✅ Documentation   │
│  ✅ Secret Scan     │
│                      │
│  Output: Pass/Fail   │
└──────────────────────┘
```

### Pipeline 2: `infra-deploy.yml` (Tests + Deploy)
**Purpose:** Deploy infrastructure after testing
**Deployment:** ✅ Yes
**Runs On:**
- Push to main (auto-deploy dev)
- Manual trigger (any environment)

```
┌──────────────────────────────────────┐
│  infra-deploy.yml                    │
│                                      │
│  1. ⬇️  Call infra-test.yml         │
│     └─ Wait for tests to pass       │
│                                      │
│  2. 📋 Determine environments        │
│     └─ needs: run-tests              │
│                                      │
│  3. 📝 Terraform Plan                │
│                                      │
│  4. ⏸️  Approval Gate (test/prod)    │
│                                      │
│  5. 🚀 Terraform Apply               │
│                                      │
│  6. 🔧 Bootstrap GitOps              │
│                                      │
│  Output: Infrastructure deployed     │
└──────────────────────────────────────┘
```

---

## Trigger Matrix

| Event | Test Pipeline | Deploy Pipeline | Environment | Approval |
|-------|--------------|-----------------|-------------|----------|
| **PR Opened** | ✅ Runs | ❌ Skipped | N/A | N/A |
| **Push to main** | ✅ Called by deploy | ✅ Runs | dev | Auto |
| **Manual (dev)** | ✅ Called by deploy | ✅ Runs | dev | Auto |
| **Manual (test)** | ✅ Called by deploy | ✅ Runs | test | Required |
| **Manual (prod)** | ✅ Called by deploy | ✅ Runs | prod | Required (2+) |

---

## Flow Diagrams

### Pull Request Flow
```
PR Created/Updated
    ↓
infra-test.yml triggered
    ↓
Run all tests (5-7 min)
    ↓
✅ Pass → Post "✅ All tests passed" on PR
❌ Fail → Post "❌ Tests failed" on PR
    ↓
END (no deployment)
```

### Push to Main Flow
```
Code merged to main
    ↓
infra-deploy.yml triggered
    ↓
Call infra-test.yml (reusable workflow)
    ↓
Tests pass?
  ├─ ❌ No  → STOP, notify
  └─ ✅ Yes → Continue
        ↓
    Determine: env=dev
        ↓
    Terraform plan (dev)
        ↓
    Terraform apply (auto-approved)
        ↓
    Bootstrap GitOps
        ↓
    ✅ Dev deployed
```

### Manual Production Deploy Flow
```
Engineer triggers workflow
Input: env=prod, action=apply
    ↓
infra-deploy.yml triggered
    ↓
Call infra-test.yml
    ↓
Tests pass?
  ├─ ❌ No  → STOP
  └─ ✅ Yes → Continue
        ↓
    Terraform plan (prod)
        ↓
    ⏸️  Wait for approval
    (prod-approval environment)
    (Requires 2+ reviewers)
        ↓
    Reviewers approve
        ↓
    Terraform apply
        ↓
    Bootstrap GitOps
        ↓
    ✅ Production deployed
```

---

## Key Concepts

### Reusable Workflow
`infra-test.yml` is a **reusable workflow** that can be called by other workflows:

```yaml
# In infra-test.yml
on:
  workflow_call:  # ← Allows other workflows to call this
  pull_request:
  push:
  workflow_dispatch:
```

### Hard Dependency
Deployment CANNOT proceed without tests:

```yaml
# In infra-deploy.yml
jobs:
  run-tests:
    uses: ./.github/workflows/infra-test.yml  # Call test pipeline
  
  determine-environments:
    needs: run-tests  # ← BLOCKS until tests complete
  
  terraform-plan:
    needs: determine-environments  # ← Indirectly waits for tests
```

---

## Why Two Pipelines?

### ✅ Advantages
1. **Separation of Concerns** - Testing vs Deployment
2. **Reusability** - Tests can be called by multiple workflows
3. **Fast Feedback** - Can run tests without deployment
4. **Safety** - Clear gate between validation and changes
5. **Flexibility** - Different triggers for different purposes

### ❌ Why Not One Pipeline?
- Can't run tests independently
- More complex conditional logic
- Harder to maintain
- Less flexible

---

## File Locations

```
sharedinfra/
├── .github/workflows/
│   ├── infra-test.yml       ← Tests only (reusable)
│   ├── infra-deploy.yml     ← Deploy (calls test)
│   └── ci-cd.yml            ← Application CI/CD
│
└── docs/
    ├── PIPELINE_ARCHITECTURE.md      ← Detailed explanation
    ├── INFRA_PIPELINE_SETUP.md       ← Deployment setup
    └── INFRA_TESTING_GUIDE.md        ← Testing guide
```

---

## Quick Commands

### Run Tests Only
```bash
# Via GitHub UI
Actions → Infrastructure Tests → Run workflow

# Result: Tests run, no deployment
```

### Deploy to Dev
```bash
# Via Git
git push origin main  # If terraform/ changed

# Result: Tests run → Auto-deploy dev
```

### Deploy to Production
```bash
# Via GitHub UI
Actions → Infrastructure Deployment → Run workflow
  Environment: prod
  Action: apply
  Auto-approve: false

# Result: Tests run → Manual approval → Deploy prod
```

---

## Interview Answer

**Question:** "How do your infrastructure pipelines work?"

**Answer:**
> "We use a two-pipeline approach with clear separation:
> 
> The **test pipeline** runs on every PR and can be triggered independently. It performs format checks, linting with TFLint, security scanning with Checkov, Terraform validation, and dry-run planning. This gives developers fast feedback without any deployment risk.
> 
> The **deployment pipeline** calls the test pipeline first as a reusable workflow using GitHub Actions' `workflow_call` feature. It has a hard dependency via `needs: run-tests`, so deployment jobs literally cannot start until all tests pass. This is enforced at the platform level.
> 
> For PRs, only tests run. For pushes to main, tests run then dev auto-deploys. For production, tests run, terraform plan executes, then we pause for manual approval with 2+ reviewers before applying changes.
> 
> This demonstrates defense-in-depth: automated testing + approval gates + environment isolation. The reusable workflow pattern also means we can call the same tests from multiple pipelines, ensuring consistency."

---

## Status Badges

Add to README.md:
```markdown
[![Infrastructure Tests](https://github.com/YOUR_ORG/sharedinfra/actions/workflows/infra-test.yml/badge.svg)](https://github.com/YOUR_ORG/sharedinfra/actions/workflows/infra-test.yml)
[![Infrastructure Deploy](https://github.com/YOUR_ORG/sharedinfra/actions/workflows/infra-deploy.yml/badge.svg)](https://github.com/YOUR_ORG/sharedinfra/actions/workflows/infra-deploy.yml)
```
