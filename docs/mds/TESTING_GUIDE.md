# GridOS Testing Guide

This document describes the complete testing strategy for the GridOS SCADA monitoring system.

## Testing Strategy Overview

Our CI/CD pipeline includes multiple layers of testing and security validation:

### 1. **Unit Tests**
- **Location**: `src/**/*.test.js`
- **Purpose**: Test individual functions and components in isolation
- **Run Command**: `npm test`
- **Coverage Target**: 70% (branches, functions, lines, statements)

### 2. **Dependency Scanning**
- **Tools**: npm audit + Snyk
- **Purpose**: Detect vulnerabilities in dependencies
- **Threshold**: HIGH and CRITICAL vulnerabilities
- **Runs**: On every build

### 3. **Container Security Scanning**
- **Tool**: Trivy
- **Purpose**: Scan Docker images for vulnerabilities
- **Severity**: CRITICAL, HIGH
- **Results**: Uploaded to GitHub Security tab

### 4. **Linting**
- **Tool**: ESLint
- **Purpose**: Code quality and style enforcement
- **Run Command**: `npm run lint`

### 5. **Smoke Tests**
- **Purpose**: Basic health and availability checks
- **Runs**: After deployment to dev/test
- **Tests**:
  - Health endpoint (`/health`)
  - SCADA status endpoint (`/api/v1/scada/status`)
  - Metrics endpoint (`/metrics`)

### 6. **Integration Tests**
- **Location**: `tests/integration/`
- **Purpose**: Test API endpoints and system interactions
- **Run Command**: `npm run test:integration`
- **Tests**:
  - SCADA data ingestion and retrieval
  - Time series data queries
  - Alarm management
  - Database connectivity
  - Metrics exposure

## Running Tests Locally

### Prerequisites
```bash
# Install dependencies
cd tests
npm install
```

### Run All Tests
```bash
npm test
```

### Run Unit Tests Only
```bash
npm run test:unit
```

### Run Integration Tests
```bash
# Set API endpoint
export API_URL=http://localhost:3000
export TEST_ENV=dev

# Run tests
npm run test:integration
```

### Run with Coverage
```bash
npm run test:coverage
```

### Watch Mode (Development)
```bash
npm run test:watch
```

## Code Coverage

### Current Thresholds
- **Branches**: 70%
- **Functions**: 70%
- **Lines**: 70%
- **Statements**: 70%

### Viewing Coverage Reports
After running tests with coverage:
```bash
# View summary in terminal
cat coverage/coverage-summary.json

# Open HTML report
open coverage/lcov-report/index.html  # macOS
start coverage/lcov-report/index.html  # Windows
```

## CI/CD Pipeline Testing Flow

### For Feature/Develop Branches (Dev Environment)
1. ✅ Build Docker image
2. ✅ **npm audit** - Dependency vulnerability scan
3. ✅ **Snyk scan** - Additional dependency analysis
4. ✅ **Unit tests with coverage** - 70% threshold
5. ✅ **Trivy scan** - Container security
6. ✅ **Linting** - Code quality
7. ✅ Deploy to dev/test
8. ✅ **Smoke tests** - Basic health checks
9. ✅ **Integration tests** - Full API validation
10. ✅ Monitor Argo Rollout

### For Main Branch (Production)
1. ✅ All tests from above
2. ✅ **Manual approval** - Production gate
3. ✅ Deploy to production
4. ✅ **Smoke tests** - Production health validation

## Integration Test Structure

```
tests/
├── package.json                      # Test dependencies & config
├── integration/
│   ├── scada.integration.test.js    # SCADA endpoint tests
│   └── health.integration.test.js   # Health & system tests
└── unit/
    └── (app-specific unit tests)
```

## Key Integration Test Scenarios

### SCADA Data Tests
- ✅ Data ingestion (POST /api/v1/scada/data)
- ✅ Data retrieval (GET /api/v1/scada/data)
- ✅ Time series queries
- ✅ Status monitoring
- ✅ Alarm management
- ✅ Invalid data rejection

### Health & Monitoring Tests
- ✅ Overall health status
- ✅ Database connectivity
- ✅ Readiness/liveness probes
- ✅ Prometheus metrics exposure
- ✅ API version info
- ✅ Error handling (404, 400, 422)

## Security Scanning Details

### npm audit
```bash
# High and moderate severity checks
npm audit --audit-level=moderate
```

### Snyk Integration
Requires `SNYK_TOKEN` secret in GitHub:
```bash
# Set in GitHub Secrets
SNYK_TOKEN=your-snyk-api-token
```

### Trivy Container Scan
Scans for:
- OS package vulnerabilities
- Language-specific vulnerabilities (npm)
- Configuration issues
- Exposed secrets

## Codecov Integration

Coverage reports are uploaded to Codecov for tracking over time:
- Badge in README
- PR comments with coverage diff
- Historical trend analysis

### Setup
Add `CODECOV_TOKEN` to GitHub Secrets.

## Best Practices

1. **Write tests before code** (TDD when possible)
2. **Keep unit tests fast** (< 1s per test)
3. **Integration tests should be idempotent** (clean up test data)
4. **Use meaningful test descriptions**
5. **Mock external dependencies in unit tests**
6. **Test error cases, not just happy paths**
7. **Maintain 70%+ code coverage**
8. **Review security scan results weekly**

## Troubleshooting

### Integration Tests Failing
```bash
# Check API is running
curl http://localhost:3000/health

# Check environment variables
echo $API_URL
echo $TEST_ENV

# Run with verbose output
npm run test:integration -- --verbose
```

### Coverage Below Threshold
```bash
# See which files need tests
npm run test:coverage

# Check coverage report
open coverage/lcov-report/index.html
```

### Dependency Vulnerabilities
```bash
# View audit report
npm audit

# Fix automatically (if possible)
npm audit fix

# Fix with breaking changes
npm audit fix --force
```

## Interview Talking Points

✅ **Multi-layer testing strategy**: Unit, integration, smoke tests
✅ **Security-first approach**: Dependency + container scanning
✅ **Code quality gates**: 70% coverage threshold, linting
✅ **Automated quality checks**: Every PR and push
✅ **Production safety**: Manual approval + comprehensive testing
✅ **Monitoring integration**: Prometheus metrics validation
✅ **Database validation**: Connection pool health checks
✅ **GitOps alignment**: Tests run before deployment

## Related Documentation

- [CI/CD Pipeline](.github/workflows/ci-cd.yml)
- [Infrastructure Pipeline](.github/workflows/infra-deploy.yml)
- [Branching Strategy](docs/BRANCHING_STRATEGY.md)
- [GitOps Flow](docs/GITOPS_COMPLETE_FLOW.md)
