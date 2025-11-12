# Infrastructure Pipeline Architecture

## How the Pipelines Work Together

We have **TWO separate pipelines** that work together:

### 1. Infrastructure Tests Pipeline (`infra-test.yml`)
**Standalone testing** - Can run independently

### 2. Infrastructure Deployment Pipeline (`infra-deploy.yml`)
**Includes testing** - Calls test pipeline first, then deploys

---

## Flow Diagrams

### Scenario 1: Pull Request (Tests Only)
```
Developer opens PR with terraform changes
    ↓
TRIGGER: infra-test.yml
    ↓
┌─────────────────────────────────────────┐
│ Run Tests in Parallel:                  │
│ ✅ Terraform Format                     │
│ ✅ TFLint (dev/test/prod)              │
│ ✅ Checkov Security                     │
│ ✅ Terraform Validate                   │
│ ✅ Plan Dry Run                         │
│ ✅ Documentation Check                  │
│ ✅ Variable Validation                  │
└─────────────────────────────────────────┘
    ↓
Post results as PR comment
    ↓
✅ Pass → Approve PR
❌ Fail → Request changes

NO DEPLOYMENT HAPPENS
```

### Scenario 2: Push to Main (Tests + Auto-Deploy Dev)
```
Developer merges PR to main
    ↓
TRIGGER: infra-deploy.yml (due to terraform/ changes)
    ↓
┌─────────────────────────────────────────┐
│ Job 1: run-tests                        │
│   uses: ./.github/workflows/infra-test.yml │
│   (Runs entire test suite)              │
└─────────────────────────────────────────┘
    ↓
Tests Pass?
    ├─ ❌ No  → STOP, notify failure
    └─ ✅ Yes → Continue
          ↓
┌─────────────────────────────────────────┐
│ Job 2: determine-environments           │
│   needs: run-tests                      │
│   Output: ["dev"]                       │
└─────────────────────────────────────────┘
    ↓
┌─────────────────────────────────────────┐
│ Job 3: terraform-plan (dev)             │
│   needs: determine-environments         │
└─────────────────────────────────────────┘
    ↓
┌─────────────────────────────────────────┐
│ Job 4: terraform-apply (dev)            │
│   Auto-approved for dev                 │
└─────────────────────────────────────────┘
    ↓
┌─────────────────────────────────────────┐
│ Job 5: bootstrap-gitops (dev)           │
│   Install Argo CD if not exists         │
└─────────────────────────────────────────┘
    ↓
✅ Dev environment deployed!
```

### Scenario 3: Manual Deployment to Production
```
Engineer clicks "Run workflow" in GitHub UI
Selects: environment=prod, action=apply
    ↓
TRIGGER: infra-deploy.yml (manual)
    ↓
┌─────────────────────────────────────────┐
│ Job 1: run-tests                        │
│   uses: ./.github/workflows/infra-test.yml │
│   (Runs entire test suite)              │
└─────────────────────────────────────────┘
    ↓
Tests Pass?
    ├─ ❌ No  → STOP, notify failure
    └─ ✅ Yes → Continue
          ↓
┌─────────────────────────────────────────┐
│ Job 2: determine-environments           │
│   Output: ["prod"]                      │
└─────────────────────────────────────────┘
    ↓
┌─────────────────────────────────────────┐
│ Job 3: terraform-plan (prod)            │
└─────────────────────────────────────────┘
    ↓
┌─────────────────────────────────────────┐
│ Job 4: manual-approval-prod             │
│   ⏸️  PAUSED - Awaiting approval        │
│   Environment: prod-approval            │
│   Required reviewers: 2+                │
└─────────────────────────────────────────┘
    ↓ (Senior engineers approve)
┌─────────────────────────────────────────┐
│ Job 5: terraform-apply-with-approval    │
│   Apply approved plan                   │
└─────────────────────────────────────────┘
    ↓
┌─────────────────────────────────────────┐
│ Job 6: bootstrap-gitops (prod)          │
│   Install Argo CD if not exists         │
└─────────────────────────────────────────┘
    ↓
✅ Production deployed!
```

---

## Key Points

### ✅ Advantages of This Approach

1. **Reusable Tests**
   - Test pipeline can run independently for quick validation
   - Same tests run before every deployment (no drift)
   - Tests can be triggered manually without deploying

2. **Clear Separation**
   - Test pipeline = Validation only (no side effects)
   - Deploy pipeline = Changes infrastructure (with tests first)

3. **Flexible Triggers**
   - PRs → Run tests only
   - Push to main → Run tests + deploy dev
   - Manual → Run tests + deploy any env

4. **Safety**
   - Deployment CANNOT proceed if tests fail
   - `needs: run-tests` creates hard dependency

### 📋 Pipeline Files

```
.github/workflows/
├── infra-test.yml          # Standalone testing pipeline
│   ├── Can run independently
│   ├── Triggered by: PRs, pushes, manual
│   └── No deployment actions
│
└── infra-deploy.yml        # Deployment pipeline (includes tests)
    ├── Calls infra-test.yml first
    ├── Triggered by: pushes to main, manual
    └── Deploys after tests pass
```

---

## Alternative Approach: Single Unified Pipeline

If you prefer a **single pipeline**, here's how it would work:

```yaml
# .github/workflows/infra-unified.yml
name: Infrastructure CI/CD

on:
  pull_request:
    paths: ['terraform/**']
  push:
    branches: [main]
    paths: ['terraform/**']
  workflow_dispatch:
    inputs:
      environment: ...
      action: ...

jobs:
  # Stage 1: Always run tests
  tests:
    name: Test Infrastructure
    runs-on: ubuntu-latest
    steps:
      - name: Format check
      - name: TFLint
      - name: Checkov
      - name: Validate
      - name: Plan

  # Stage 2: Deploy (only if not PR)
  deploy:
    name: Deploy Infrastructure
    needs: tests
    if: github.event_name != 'pull_request'
    runs-on: ubuntu-latest
    steps:
      - name: Terraform apply
      - name: Bootstrap GitOps
```

### Comparison

| Approach | Pros | Cons |
|----------|------|------|
| **Two Pipelines** (Current) | ✅ Tests can run independently<br>✅ Clearer separation of concerns<br>✅ Easier to maintain<br>✅ Better for large teams | ⚠️ Two files to manage<br>⚠️ Slightly more complex setup |
| **Single Pipeline** | ✅ One file<br>✅ Simpler mental model | ⚠️ Can't run tests independently<br>⚠️ More complex conditionals<br>⚠️ Harder to debug |

---

## When Each Pipeline Runs

### `infra-test.yml` Runs:
1. ✅ **Pull Request** - Any PR touching `terraform/`
2. ✅ **Push to main** - Called by `infra-deploy.yml`
3. ✅ **Manual trigger** - "Run workflow" button
4. ✅ **Called by other workflows** - Reusable workflow

**Purpose:** Validate code quality/security

### `infra-deploy.yml` Runs:
1. ✅ **Push to main** - Auto-deploy dev
2. ✅ **Manual trigger** - Deploy any environment
3. ❌ **NOT on PRs** - Only testing on PRs

**Purpose:** Deploy infrastructure (after tests pass)

---

## Code Connection

### In `infra-deploy.yml`:
```yaml
jobs:
  # This calls the test pipeline as a reusable workflow
  run-tests:
    name: Run Infrastructure Tests
    uses: ./.github/workflows/infra-test.yml  # ← Calls test pipeline
    secrets: inherit                           # Pass all secrets
  
  # This job waits for tests
  determine-environments:
    needs: run-tests  # ← Blocks until tests pass
    ...
  
  # All subsequent jobs depend on determine-environments
  # So they ALL wait for tests to pass first
  terraform-plan:
    needs: determine-environments  # ← Indirectly waits for tests
    ...
```

### Test Pipeline as Reusable Workflow

In `infra-test.yml`, add at the top:
```yaml
on:
  workflow_call:  # ← Allows other workflows to call this
  pull_request:
    paths: ['terraform/**']
  push:
    branches: [main]
    paths: ['terraform/**']
```

---

## Recommendation for GE Interview

**Current approach (two pipelines) is BETTER because:**

1. **Professional Practice** - Matches enterprise patterns (e.g., Google, Netflix)
2. **Demonstrates Understanding** - Shows you know separation of concerns
3. **Reusability** - Test pipeline can be called by multiple workflows
4. **Flexibility** - Can run tests without deployment side effects

### Interview Talking Points

> **"We use a two-pipeline approach for infrastructure automation:**
> 
> **Pipeline 1: Infrastructure Tests** - Runs on every PR and can be triggered independently. Performs format checks, linting, security scanning, validation, and dry-run planning. This gives developers fast feedback without any deployment risk.
> 
> **Pipeline 2: Infrastructure Deployment** - Calls the test pipeline first as a reusable workflow, then proceeds with deployment only if all tests pass. This ensures we never deploy untested code.
> 
> The key advantage is the `needs: run-tests` dependency - deployment jobs literally cannot start until tests complete successfully. This is enforced at the GitHub Actions level, not just a manual process.
> 
> For PRs, only tests run. For pushes to main, tests run first then dev auto-deploys. For production, tests run, then we require manual approval gates with 2+ reviewers before applying changes.
> 
> This demonstrates defense-in-depth: automated testing + approval gates + environment isolation."

---

## Visual Summary

```
┌─────────────────────────────────────────────────────────────┐
│                    PULL REQUEST                              │
│                                                              │
│  Trigger: infra-test.yml                                    │
│  Action:  Tests only, no deployment                         │
│  Result:  PR comment with test results                      │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                    PUSH TO MAIN                              │
│                                                              │
│  Trigger: infra-deploy.yml                                  │
│  Step 1:  Run infra-test.yml (all tests)                   │
│  Step 2:  Deploy to dev (if tests pass)                    │
│  Step 3:  Bootstrap GitOps (if needed)                     │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                    MANUAL TRIGGER                            │
│                                                              │
│  Trigger: infra-deploy.yml                                  │
│  Step 1:  Run infra-test.yml (all tests)                   │
│  Step 2:  Terraform plan                                    │
│  Step 3:  Wait for approval (test/prod only)               │
│  Step 4:  Terraform apply                                   │
│  Step 5:  Bootstrap GitOps (if needed)                     │
└─────────────────────────────────────────────────────────────┘
```

The current setup is optimal for production use! 🚀
