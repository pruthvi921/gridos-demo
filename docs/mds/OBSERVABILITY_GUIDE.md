# Observability, Alerting & Incident Automation - Complete Guide

## Overview

We've implemented a **production-grade observability stack** with automated incident response for GridOS SCADA monitoring system.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                     OBSERVABILITY STACK                             │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌──────────────┐      ┌──────────────┐      ┌──────────────┐    │
│  │  Prometheus  │─────>│   Grafana    │      │    Loki      │    │
│  │   (Metrics)  │      │ (Dashboard)  │      │   (Logs)     │    │
│  └──────────────┘      └──────────────┘      └──────────────┘    │
│         │                                            │             │
│         │ scrapes                                    │ collects    │
│         ↓                                            ↓             │
│  ┌─────────────────────────────────────────────────────────┐      │
│  │           GridOS SCADA Application Pods                 │      │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐             │      │
│  │  │ Pod 1    │  │ Pod 2    │  │ Pod 3    │             │      │
│  │  │ /metrics │  │ /metrics │  │ /metrics │             │      │
│  │  └──────────┘  └──────────┘  └──────────┘             │      │
│  └─────────────────────────────────────────────────────────┘      │
│         │                                                          │
│         │ evaluates                                                │
│         ↓                                                          │
│  ┌──────────────────────────────────────────┐                     │
│  │     Alert Rules (Prometheus Rules)       │                     │
│  │  • High error rate (>5%)                 │                     │
│  │  • High latency (p95 >500ms)             │                     │
│  │  • SCADA ingestion stopped               │                     │
│  │  • Database connection failed            │                     │
│  │  • Pod crash looping                     │                     │
│  └──────────────────────────────────────────┘                     │
│         │ fires alerts                                             │
│         ↓                                                          │
│  ┌──────────────────────────────────────────┐                     │
│  │         AlertManager                     │                     │
│  │  • Routes alerts by severity             │                     │
│  │  • Deduplicates alerts                   │                     │
│  │  • Groups related alerts                 │                     │
│  └──────────────────────────────────────────┘                     │
│         │                                                          │
│         ├──────────────┬───────────────┬─────────────┐           │
│         ↓              ↓               ↓             ↓           │
│    ┌────────┐    ┌─────────┐    ┌──────────┐  ┌──────────┐     │
│    │ Slack  │    │PagerDuty│    │ Runbooks │  │  Email   │     │
│    │Webhook │    │ Critical│    │Automation│  │  Alerts  │     │
│    └────────┘    └─────────┘    └──────────┘  └──────────┘     │
│                                       │                           │
│                                       ↓                           │
│                          ┌─────────────────────────┐             │
│                          │ Automated Remediation   │             │
│                          │  • Auto rollback        │             │
│                          │  • Pod restart          │             │
│                          │  • Scale up             │             │
│                          │  • Log collection       │             │
│                          └─────────────────────────┘             │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

---

## Components

### 1. Prometheus (Metrics Collection)

**What it does:**
- Scrapes metrics from GridOS pods every 30 seconds
- Stores time-series data (HTTP requests, error rates, latency, CPU, memory)
- Evaluates alert rules continuously
- Provides PromQL query language for analysis

**Metrics Collected:**
```
# HTTP Metrics
http_requests_total{app="gridos", status="200"}
http_request_duration_seconds{app="gridos", endpoint="/api/v1/scada/data"}

# SCADA-specific Metrics
gridos_scada_readings_total
gridos_scada_devices_online
gridos_alarm_threshold_breaches_total

# System Metrics
container_cpu_usage_seconds_total{namespace="gridos"}
container_memory_working_set_bytes{namespace="gridos"}

# Database Metrics
gridos_database_connections_active
gridos_database_query_duration_seconds
gridos_database_connection_errors_total
```

**Configuration:** `monitoring/prometheus/values-dev.yaml`, `values-prod.yaml`

---

### 2. Grafana (Visualization & Dashboards)

**What it does:**
- Visualizes Prometheus metrics in real-time dashboards
- Shows historical trends (7 days dev, 30 days prod)
- Provides drill-down capabilities
- Supports alerting (though we use Prometheus alerts)

**Dashboards Created:**
1. **GridOS System Overview** (`gridos-system-overview.json`)
   - Request rate, error rate, latency
   - Pod status, CPU, memory
   - SCADA data ingestion rate
   - Database connection pool status

2. **GridOS SLO Dashboard** (`gridos-slo-dashboard.json`)
   - Availability SLO (target: 99.9%)
   - Latency SLO (p95 < 500ms)
   - Error budget tracking
   - Incident timeline

3. **Kubernetes Cluster Monitoring** (Grafana ID: 7249)
   - Node resource usage
   - Pod distribution
   - Network traffic

4. **Node Exporter Full** (Grafana ID: 1860)
   - CPU, memory, disk per node
   - Network I/O
   - System load

**Access:**
- Dev: `https://grafana-dev.gridos.example.com`
- Prod: `https://grafana.gridos.example.com`
- Username: `admin`
- Password: From Azure Key Vault

---

### 3. AlertManager (Alert Routing)

**What it does:**
- Receives alerts from Prometheus
- Groups related alerts (e.g., all pod failures together)
- Deduplicates repeated alerts
- Routes based on severity and labels
- Manages silences and inhibitions

**Routing Rules:**

```
Critical Alerts (severity: critical)
    ↓
PagerDuty (creates incident, pages on-call)
    AND
Slack #gridos-incidents channel
    AND
Automated Runbook (if available)

High Alerts (severity: high)
    ↓
Slack #gridos-prod-alerts
    AND
PagerDuty (low-urgency notification)

Warning Alerts (severity: warning)
    ↓
Slack #gridos-alerts
    (no page)
```

**Alert Grouping:**
- Wait 10 seconds before sending first alert (group similar alerts)
- Group by: alertname, cluster, service
- Repeat alerts every 4 hours if not resolved

---

### 4. Loki (Log Aggregation)

**What it does:**
- Collects logs from all pods
- Indexes by labels (namespace, pod, container)
- Provides LogQL query language
- Integrates with Grafana for log exploration

**Usage:**
```bash
# View GridOS logs in Grafana
{namespace="gridos", app="gridos"} |= "error"

# Find database connection errors
{namespace="gridos"} |~ "database connection.*failed"

# Tail logs in real-time
{namespace="gridos"} | json | line_format "{{.message}}"
```

---

## Alert Rules

### Critical Alerts (Page On-Call)

#### 1. GridOS API Down
```yaml
alert: GridOSAPIDown
expr: up{job="gridos"} == 0
for: 1m
```
**Meaning:** All GridOS pods are unreachable  
**Impact:** SCADA monitoring completely down, grid operators blind  
**Action:** Page on-call immediately, check AKS node health

#### 2. High Error Rate
```yaml
alert: GridOSHighErrorRate
expr: (sum(rate(http_requests_total{app="gridos",status=~"5.."}[5m])) /
      sum(rate(http_requests_total{app="gridos"}[5m]))) > 0.02
for: 2m
```
**Meaning:** >2% of requests returning 500 errors  
**Impact:** Users experiencing failures  
**Action:** Auto-rollback if recent deployment, otherwise page on-call

#### 3. Database Connection Failed
```yaml
alert: GridOSDatabaseConnectionFailed
expr: rate(gridos_database_connection_errors_total[5m]) > 0
for: 1m
```
**Meaning:** Cannot connect to PostgreSQL  
**Impact:** No SCADA data being saved  
**Action:** Check database status, restart pods, page on-call

#### 4. SCADA Ingestion Stopped
```yaml
alert: GridOSSCADAIngestionStopped
expr: rate(gridos_scada_readings_total[5m]) == 0
for: 5m
```
**Meaning:** No sensor data received for 5 minutes  
**Impact:** Grid monitoring blind, operators can't see equipment status  
**Action:** Check data sources, restart ingestion pods, alert grid operators

### High Alerts (Slack + Low-Urgency Page)

#### 5. High Latency
```yaml
alert: GridOSHighLatency
expr: histogram_quantile(0.95,
      sum(rate(http_request_duration_seconds_bucket{app="gridos"}[5m])) by (le)
    ) > 0.3
for: 5m
```
**Meaning:** 95th percentile latency > 300ms  
**Impact:** Slow response times, degraded user experience

#### 6. Pod Crash Looping
```yaml
alert: GridOSPodCrashLooping
expr: rate(kube_pod_container_status_restarts_total{namespace="gridos"}[15m]) > 0
for: 5m
```
**Meaning:** Pod restarting frequently  
**Impact:** Reduced capacity, potential data loss

### Warning Alerts (Slack Only)

#### 7. High Memory Usage
```yaml
alert: GridOSHighMemoryUsage
expr: (sum(container_memory_working_set_bytes{namespace="gridos",container="gridos"}) /
      sum(container_spec_memory_limit_bytes{namespace="gridos",container="gridos"})) > 0.85
for: 10m
```
**Meaning:** Memory usage >85% of limit  
**Impact:** Risk of OOM kills

#### 8. CPU Throttling
```yaml
alert: GridOSCPUThrottling
expr: rate(container_cpu_cfs_throttled_seconds_total{namespace="gridos"}[5m]) > 0.5
for: 5m
```
**Meaning:** CPU being throttled due to limits  
**Impact:** Slower response times

---

## Automated Runbooks

### What are Runbooks?

Automated scripts that execute when specific alerts fire, performing remediation actions without human intervention.

### Available Runbooks:

#### 1. High Error Rate Auto-Rollback
**File:** `monitoring/runbooks/high-error-rate-rollback.yaml`

**Trigger:** Error rate >5% within 30 minutes of deployment

**Actions:**
1. Detect recent deployment
2. Collect error logs
3. Analyze error patterns (database, memory, timeout errors)
4. Automatically rollback using Argo Rollouts
5. Verify error rate returns to normal
6. Post results to Slack

**Safety:** Only rolls back if deployment was in last 30 minutes

#### 2. Database Connection Recovery (Planned)
**Trigger:** Database connection errors detected

**Actions:**
1. Check PostgreSQL pod status
2. Test connectivity from debug pod
3. Restart application pods
4. Scale up database if needed
5. Alert if database itself is down

#### 3. SCADA Ingestion Recovery (Planned)
**Trigger:** No SCADA readings for 10 minutes

**Actions:**
1. Check data source connectivity
2. Verify message queue status
3. Restart ingestion pods
4. Failover to backup endpoint
5. Alert grid operators via PagerDuty

### Runbook Execution Flow:

```
1. Prometheus detects condition (e.g., error rate >5%)
2. Alert fires → AlertManager
3. AlertManager sends webhook to Kubernetes API
4. Kubernetes Job created with runbook script
5. Runbook executes automated remediation
6. Results posted to Slack
7. If successful → Alert resolves
8. If failed → Page on-call engineer
```

### Safety Mechanisms:

✅ **Rate limiting:** Max 3 executions per hour per alert  
✅ **Dry-run mode:** Test without making changes  
✅ **Manual override:** On-call can disable automation  
✅ **Audit logging:** All actions logged  
✅ **Rollback capability:** Can undo automated actions  

---

## Installation

### 1. Install Observability Stack

```bash
# Dev environment
cd scripts
./install-observability.sh dev

# Production environment
./install-observability.sh prod
```

This installs:
- Prometheus Operator
- Grafana
- AlertManager
- Loki (log aggregation)
- Node Exporter
- Kube State Metrics

### 2. Configure Secrets

```bash
# Create secret for Slack webhooks
kubectl create secret generic alert-secrets \
  --namespace monitoring \
  --from-literal=slack-webhook-url='https://hooks.slack.com/services/YOUR/WEBHOOK/URL'

# Create secret for PagerDuty
kubectl create secret generic pagerduty-secrets \
  --namespace monitoring \
  --from-literal=service-key='YOUR_PAGERDUTY_INTEGRATION_KEY'
```

### 3. Deploy via Argo CD (GitOps)

```bash
# Apply observability Argo CD application
kubectl apply -f argocd/applications/observability.yaml

# Verify sync
argocd app get observability-dev
```

### 4. Access Dashboards

```bash
# Port-forward Grafana
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

# Get admin password
kubectl get secret -n monitoring kube-prometheus-stack-grafana \
  -o jsonpath='{.data.admin-password}' | base64 -d

# Open browser
open http://localhost:3000
```

---

## Incident Response Workflow

### Automatic (via Runbooks)

```
1. Alert fires (e.g., high error rate)
2. AlertManager sends to Slack + PagerDuty
3. Runbook automatically triggered
4. Runbook performs diagnosis:
   - Collect logs
   - Check recent deployments
   - Analyze error patterns
5. Runbook takes action:
   - Rollback deployment if recent
   - Restart pods if memory issue
   - Scale up if resource constrained
6. Runbook verifies fix
7. Post results to Slack
8. If successful → Alert resolves automatically
9. If failed → Page on-call for manual intervention
```

### Manual (On-Call Engineer)

```
1. Receive PagerDuty page
2. Check Slack for context
3. Open Grafana dashboard
4. Review runbook URL from alert
5. If not automated, follow runbook steps manually
6. Resolve incident
7. Update post-mortem
```

---

## Metrics & SLOs

### Service Level Objectives (SLOs)

| Metric | Target | Measurement |
|--------|--------|-------------|
| **Availability** | 99.9% | (non-5xx requests / total requests) |
| **Latency (p95)** | <500ms | 95th percentile response time |
| **Latency (p99)** | <1s | 99th percentile response time |
| **Error Rate** | <0.1% | 5xx errors / total requests |
| **SCADA Ingestion** | 99.99% uptime | Data received continuously |

### Error Budget

- **Monthly availability target:** 99.9% = 43 minutes downtime allowed
- **Error budget tracking:** Grafana SLO dashboard
- **Alert:** If error budget <10%, freeze deployments

---

## Interview Talking Points

### Q: "How do you monitor your applications?"

> *"We use a complete observability stack with Prometheus for metrics collection, Grafana for visualization, and Loki for logs. Prometheus scrapes metrics from GridOS pods every 30 seconds, evaluates alert rules, and sends alerts to AlertManager. We have comprehensive dashboards showing request rates, error rates, latency, SCADA data ingestion, and database health. All critical alerts are routed to PagerDuty and trigger automated runbooks."*

### Q: "What happens when an alert fires?"

> *"Depends on severity. Critical alerts like 'API down' or 'database connection failed' page the on-call engineer via PagerDuty immediately and post to Slack. For certain alerts like high error rates after deployment, we have automated runbooks that detect the issue, collect diagnostics, and automatically rollback. All alerts include a runbook URL with step-by-step remediation instructions."*

### Q: "How do you handle incidents?"

> *"We use a three-tier approach: automated runbooks for common issues like deployment rollbacks, AlertManager for intelligent routing and deduplication, and PagerDuty for paging humans when automation can't resolve it. Every alert has a runbook with diagnosis steps and remediation actions. We track SLOs in Grafana and have error budgets to balance reliability with feature velocity."*

### Q: "What alerts do you have configured?"

> *"We have 8 core alerts: API down (critical), high error rate (critical), database connection failed (critical), SCADA ingestion stopped (critical), high latency (high), pod crash looping (high), high memory usage (warning), and CPU throttling (warning). Critical alerts page immediately, high alerts go to Slack with low-urgency page, warnings are Slack-only. Each alert has specific thresholds tuned to avoid false positives."*

---

## Summary

✅ **Prometheus** - Metrics collection & alert evaluation  
✅ **Grafana** - 4 dashboards (system, SLO, cluster, nodes)  
✅ **AlertManager** - Smart routing (Slack, PagerDuty, Email)  
✅ **Loki** - Centralized log aggregation  
✅ **8 Alert Rules** - Critical, high, warning severity  
✅ **Automated Runbooks** - Auto-rollback on high errors  
✅ **SLO Tracking** - 99.9% availability, <500ms p95 latency  
✅ **GitOps Managed** - Deployed via Argo CD  

**Result:** Production-grade observability with automated incident response!
