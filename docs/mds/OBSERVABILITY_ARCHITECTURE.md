# Observability Stack Architecture - Complete Explanation

## How Components Work Together

### 1. Installation & Deployment

**Helm Charts Used:**
```bash
# Single command installs all components
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values monitoring/prometheus/values-dev.yaml

# This Helm chart includes:
├── Prometheus Operator (manages Prometheus instances)
├── Prometheus Server (metrics storage & querying)
├── Grafana (visualization)
├── AlertManager (alert routing)
├── Node Exporter (host metrics)
└── Kube State Metrics (K8s resource metrics)

# Loki (log aggregation) installed separately
helm install loki grafana/loki-stack \
  --namespace monitoring
```

**Why Helm inside Kubernetes cluster?**
- **In-cluster deployment**: All monitoring components run as pods inside the same K8s cluster
- **Service discovery**: Prometheus automatically discovers pods, services, and nodes
- **Low latency**: Metrics scraping happens within the cluster network
- **Security**: No external access needed for scraping
- **GitOps integration**: Argo CD manages Helm releases via `argocd/applications/observability.yaml`

---

## 2. Component Communication Flow

### A. Metrics Collection (Prometheus → GridOS)

```
┌─────────────────────────────────────────────────────────┐
│ Step 1: Pod Discovery (Kubernetes API)                 │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Prometheus ──GET pods──> Kubernetes API               │
│     │                           │                       │
│     │<──────returns pods────────┘                       │
│     │                                                   │
│     │ Filters pods with annotations:                   │
│     │   prometheus.io/scrape: "true"                   │
│     │   prometheus.io/port: "3000"                     │
│     │   prometheus.io/path: "/metrics"                 │
│     │                                                   │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ Step 2: Metrics Scraping (HTTP GET)                    │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Prometheus ──HTTP GET /metrics──> GridOS Pod          │
│     │                                    │              │
│     │<────────Prometheus format──────────┘              │
│     │                                                   │
│     │ Response Example:                                │
│     │ http_requests_total{status="200"} 1523          │
│     │ http_request_duration_seconds{p95="0.245"}      │
│     │ gridos_scada_readings_total 45321               │
│     │ gridos_alarm_breaches_total 3                   │
│     │                                                   │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ Step 3: Time-Series Storage (TSDB)                     │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Prometheus stores metrics in time-series database:    │
│                                                         │
│  ┌────────────────────────────────────────┐           │
│  │ Metric Name: http_requests_total       │           │
│  │ Labels: {app="gridos", status="200"}   │           │
│  │ Timestamp: 2025-11-12 10:00:00 → 1523 │           │
│  │ Timestamp: 2025-11-12 10:00:30 → 1538 │           │
│  │ Timestamp: 2025-11-12 10:01:00 → 1552 │           │
│  └────────────────────────────────────────┘           │
│                                                         │
│  Storage: /prometheus/data (PersistentVolume)          │
│  Retention: 7 days (dev) / 30 days (prod)             │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

**Configuration:**
```yaml
# monitoring/prometheus/values-dev.yaml
additionalScrapeConfigs:
- job_name: 'gridos'
  scrape_interval: 30s  # Scrape every 30 seconds
  kubernetes_sd_configs:
  - role: pod
    namespaces:
      names:
      - gridos  # Only scrape gridos namespace
```

---

### B. Log Collection (Loki → GridOS)

```
┌─────────────────────────────────────────────────────────┐
│ Loki Architecture                                       │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  GridOS Pod                                             │
│       │                                                 │
│       │ writes logs to stdout/stderr                   │
│       ↓                                                 │
│  Docker/containerd                                      │
│       │                                                 │
│       │ log files: /var/log/pods/                      │
│       ↓                                                 │
│  Promtail (DaemonSet)                                   │
│       │ runs on every node                             │
│       │ tails log files                                │
│       │ adds labels: namespace, pod, container         │
│       ↓                                                 │
│  Loki Server                                            │
│       │ indexes logs by labels (not content!)          │
│       │ stores compressed logs in chunks               │
│       │ provides LogQL query language                  │
│       │                                                 │
│  Storage: S3 or PersistentVolume                        │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

**Query Example:**
```logql
# Get GridOS error logs from last hour
{namespace="gridos", container="gridos"} |= "ERROR" | json
```

---

### C. Alert Evaluation (Prometheus → AlertManager)

```
┌─────────────────────────────────────────────────────────┐
│ Alert Rule Evaluation                                   │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Every 30 seconds, Prometheus:                          │
│                                                         │
│  1. Executes PromQL queries:                            │
│     ┌─────────────────────────────────────────┐       │
│     │ Alert: GridOSHighErrorRate              │       │
│     │ Query:                                  │       │
│     │   sum(rate(http_requests_total          │       │
│     │     {status=~"5..",app="gridos"}[5m]))  │       │
│     │   /                                     │       │
│     │   sum(rate(http_requests_total          │       │
│     │     {app="gridos"}[5m]))                │       │
│     │   > 0.05  # 5% threshold                │       │
│     │                                         │       │
│     │ For: 5m  # Must be true for 5 minutes  │       │
│     └─────────────────────────────────────────┘       │
│                                                         │
│  2. If condition met for duration:                      │
│     Prometheus ──fires alert──> AlertManager           │
│                                                         │
│  3. Alert includes:                                     │
│     - Alert name: GridOSHighErrorRate                  │
│     - Severity: critical                               │
│     - Labels: {app="gridos", namespace="gridos"}       │
│     - Annotations: Description, runbook URL            │
│     - Value: 0.087 (8.7% error rate)                   │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

### D. Alert Routing (AlertManager → Receivers)

```
┌─────────────────────────────────────────────────────────┐
│ AlertManager Routing Logic                              │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Incoming Alert: GridOSHighErrorRate                    │
│       │ severity: critical                              │
│       │ app: gridos                                     │
│       ↓                                                 │
│  ┌───────────────────────────────────────┐             │
│  │ Routing Tree                          │             │
│  │                                       │             │
│  │ IF severity == "critical":            │             │
│  │    → pagerduty-critical               │             │
│  │    → continue: true (also send below) │             │
│  │                                       │             │
│  │ IF app == "gridos":                   │             │
│  │    → slack-gridos (#gridos-dev)       │             │
│  │                                       │             │
│  │ DEFAULT:                              │             │
│  │    → slack-notifications              │             │
│  └───────────────────────────────────────┘             │
│       │                                                 │
│       ↓                                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌──────────────┐  │
│  │ PagerDuty   │  │ Slack       │  │ Slack        │  │
│  │ (pages      │  │ #gridos-dev │  │ #gridos-     │  │
│  │  on-call)   │  │             │  │  alerts      │  │
│  └─────────────┘  └─────────────┘  └──────────────┘  │
│                                                         │
│  Grouping: Batches alerts for 10 seconds               │
│  Deduplication: Same alert sent once every 12 hours    │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

**Configuration:**
```yaml
# monitoring/prometheus/values-dev.yaml
route:
  group_by: ['alertname', 'cluster', 'service']
  group_wait: 10s       # Wait 10s before sending (group similar alerts)
  group_interval: 10s   # Send grouped alerts every 10s
  repeat_interval: 12h  # Re-send every 12h if not resolved
```

---

### E. Automated Runbooks (AlertManager → Kubernetes Job)

```
┌─────────────────────────────────────────────────────────┐
│ Automated Remediation Workflow                          │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  1. AlertManager fires webhook:                         │
│     POST https://runbook-service/trigger                │
│     Body: {                                             │
│       "alert": "GridOSHighErrorRate",                   │
│       "severity": "critical",                           │
│       "value": 0.087                                    │
│     }                                                   │
│       │                                                 │
│       ↓                                                 │
│  2. Runbook Service creates Kubernetes Job:             │
│     kubectl create -f monitoring/runbooks/              │
│       high-error-rate-rollback.yaml                     │
│       │                                                 │
│       ↓                                                 │
│  3. Job Pod executes remediation script:                │
│     ┌─────────────────────────────────────────┐       │
│     │ #!/bin/bash                             │       │
│     │                                         │       │
│     │ # Verify error rate from Prometheus    │       │
│     │ ERROR_RATE=$(query_prometheus)          │       │
│     │                                         │       │
│     │ # Check recent deployments             │       │
│     │ LAST_DEPLOY=$(kubectl get rollout      │       │
│     │   gridos -o json | jq .status.         │       │
│     │   lastUpdated)                         │       │
│     │                                         │       │
│     │ if [[ $LAST_DEPLOY < 30m ]]; then      │       │
│     │   # Auto-rollback                      │       │
│     │   kubectl argo rollouts undo gridos    │       │
│     │                                         │       │
│     │   # Wait for rollback                  │       │
│     │   kubectl argo rollouts status gridos  │       │
│     │                                         │       │
│     │   # Verify error rate improved         │       │
│     │   NEW_ERROR_RATE=$(query_prometheus)   │       │
│     │                                         │       │
│     │   # Post to Slack                      │       │
│     │   curl -X POST $SLACK_WEBHOOK          │       │
│     │     -d "Rolled back deployment"        │       │
│     │ fi                                     │       │
│     └─────────────────────────────────────────┘       │
│       │                                                 │
│       ↓                                                 │
│  4. Results posted to Slack:                            │
│     ✅ Rollback completed                               │
│     📊 Error rate: 8.7% → 1.2%                         │
│     🔗 Logs: https://grafana/explore                    │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

### F. Visualization (Grafana → Prometheus/Loki)

```
┌─────────────────────────────────────────────────────────┐
│ Grafana Dashboard Workflow                              │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  User opens: https://grafana-dev.gridos.example.com     │
│       │                                                 │
│       ↓                                                 │
│  Dashboard: GridOS System Overview                      │
│       │                                                 │
│       │ Panel 1: Request Rate                          │
│       │   Query: rate(http_requests_total[5m])         │
│       │   → Grafana ──PromQL──> Prometheus             │
│       │   → Prometheus returns time-series data        │
│       │   → Grafana renders line chart                 │
│       │                                                 │
│       │ Panel 2: Error Logs                            │
│       │   Query: {namespace="gridos"} |= "ERROR"       │
│       │   → Grafana ──LogQL──> Loki                    │
│       │   → Loki returns log lines                     │
│       │   → Grafana renders log panel                  │
│       │                                                 │
│       │ Panel 3: SCADA Data Points                     │
│       │   Query: gridos_scada_readings_total           │
│       │   → Grafana ──PromQL──> Prometheus             │
│       │   → Prometheus returns counter value           │
│       │   → Grafana renders gauge                      │
│       │                                                 │
│  Real-time updates every 5 seconds                      │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

**Datasources configured:**
```yaml
# monitoring/prometheus/values-dev.yaml
grafana:
  datasources:
    datasources.yaml:
      apiVersion: 1
      datasources:
      - name: Prometheus
        type: prometheus
        url: http://kube-prometheus-stack-prometheus.monitoring:9090
        isDefault: true
      
      - name: Loki
        type: loki
        url: http://loki.monitoring:3100
```

---

## 3. What You Can Monitor

### A. Application Metrics

**HTTP/API Metrics:**
```promql
# Request rate by endpoint
rate(http_requests_total{app="gridos"}[5m])

# Error rate percentage
sum(rate(http_requests_total{status=~"5..",app="gridos"}[5m]))
/ sum(rate(http_requests_total{app="gridos"}[5m])) * 100

# p95 latency
histogram_quantile(0.95, 
  rate(http_request_duration_seconds_bucket[5m]))

# Requests by status code
sum by (status) (rate(http_requests_total[5m]))
```

**SCADA-Specific Metrics:**
```promql
# SCADA data ingestion rate
rate(gridos_scada_readings_total[5m])

# Active devices
gridos_scada_devices_online

# Alarm breaches
rate(gridos_alarm_threshold_breaches_total[1h])

# Data processing lag
gridos_scada_processing_lag_seconds

# Database query performance
rate(gridos_database_query_duration_seconds_sum[5m])
/ rate(gridos_database_query_duration_seconds_count[5m])
```

---

### B. Infrastructure Metrics

**Kubernetes Metrics:**
```promql
# Pod CPU usage
sum(rate(container_cpu_usage_seconds_total{namespace="gridos"}[5m]))
by (pod)

# Pod memory usage
sum(container_memory_working_set_bytes{namespace="gridos"})
by (pod) / 1024 / 1024 / 1024  # Convert to GB

# Pod restart count
sum(kube_pod_container_status_restarts_total{namespace="gridos"})
by (pod)

# Pod ready status
kube_pod_status_ready{namespace="gridos"}

# Available replicas
kube_deployment_status_replicas_available{namespace="gridos"}
```

**Node Metrics:**
```promql
# Node CPU usage
100 - (avg by (node) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Node memory usage
(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) 
/ node_memory_MemTotal_bytes * 100

# Disk usage
(node_filesystem_size_bytes - node_filesystem_avail_bytes)
/ node_filesystem_size_bytes * 100
```

---

### C. Database Metrics

```promql
# Database connection pool
gridos_database_connections_active
gridos_database_connections_idle
gridos_database_connections_max

# Query performance
rate(gridos_database_query_duration_seconds_sum[5m])
/ rate(gridos_database_query_duration_seconds_count[5m])

# Connection errors
rate(gridos_database_connection_errors_total[5m])

# Transaction rate
rate(gridos_database_transactions_total[5m])

# Deadlocks
rate(gridos_database_deadlocks_total[1h])
```

---

### D. Business Metrics

```promql
# Active SCADA devices by site
sum by (site) (gridos_scada_devices_online)

# Data quality (missing readings)
rate(gridos_scada_missing_readings_total[5m])

# Critical alarms
sum(gridos_alarms_active{severity="critical"})

# User API calls
rate(gridos_api_calls_total[5m])

# Data export rate
rate(gridos_data_exports_bytes_total[5m])
```

---

## 4. Critical Alerts Configured

### Alert Priority Levels

| Severity | Response Time | Action | Notification |
|----------|--------------|---------|-------------|
| **Critical** | Immediate (5 min) | Page on-call + Auto-remediation | PagerDuty + Slack |
| **High** | 30 minutes | Manual investigation | Slack + PagerDuty (low-priority) |
| **Warning** | Next business day | Review logs | Slack only |

---

### 1. **GridOSAPIDown** (Critical)

**What it monitors:**
```promql
up{app="gridos"} == 0
```

**Meaning:** All GridOS pods are down, API completely unavailable

**Impact:**
- No SCADA data ingestion
- Grid monitoring stopped
- Operators cannot view alarms or data
- Critical grid events may be missed

**Automated Action:** Runbook restarts pods and checks recent changes

**Configuration:**
```yaml
- alert: GridOSAPIDown
  expr: up{app="gridos"} == 0
  for: 1m
  labels:
    severity: critical
  annotations:
    summary: "GridOS API is completely down"
    description: "All GridOS pods are unavailable for {{ $value }} minutes"
    runbook_url: "https://runbooks/api-down"
```

---

### 2. **GridOSHighErrorRate** (Critical)

**What it monitors:**
```promql
(sum(rate(http_requests_total{status=~"5..",app="gridos"}[5m]))
 / sum(rate(http_requests_total{app="gridos"}[5m]))) > 0.02
```

**Meaning:** >2% of API requests returning 500 errors (production threshold)

**Impact:**
- SCADA data ingestion failures
- Alarm notifications not sent
- Grid operators see error screens
- Data loss possible

**Automated Action:** Auto-rollback if deployment happened <30 minutes ago

**Runbook Workflow:**
1. Query Prometheus for error rate
2. Check recent Argo Rollouts deployments
3. If recent deployment: `kubectl argo rollouts undo gridos`
4. Wait for rollback to complete
5. Verify error rate drops below 1%
6. Post results to Slack

---

### 3. **GridOSHighLatency** (High)

**What it monitors:**
```promql
histogram_quantile(0.95,
  rate(http_request_duration_seconds_bucket{app="gridos"}[5m])
) > 0.3
```

**Meaning:** 95th percentile response time >300ms (production threshold)

**Impact:**
- Slow dashboard loading for operators
- Delayed SCADA data updates
- Degraded user experience
- May indicate database issues

**Manual Actions:**
- Check database query performance
- Review slow query logs
- Check pod CPU/memory limits
- Verify database connection pool size

---

### 4. **GridOSDatabaseConnectionFailed** (Critical)

**What it monitors:**
```promql
gridos_database_connections_active{app="gridos"} == 0
```

**Meaning:** No active database connections

**Impact:**
- Cannot store new SCADA readings
- Cannot retrieve historical data
- Alarms cannot be saved
- Data loss for duration of outage

**Automated Action:** Runbook restarts application pods and checks database health

**Checklist:**
- [ ] PostgreSQL server running?
- [ ] Network connectivity OK?
- [ ] Connection string correct?
- [ ] Database user credentials valid?
- [ ] Connection pool exhausted?

---

### 5. **GridOSSCADAIngestionStopped** (Critical)

**What it monitors:**
```promql
rate(gridos_scada_readings_total{app="gridos"}[5m]) == 0
```

**Meaning:** No SCADA data being ingested for 5+ minutes

**Impact:**
- Grid monitoring blind spot
- Operators cannot see current conditions
- Alarms not generated
- Compliance violations possible

**Investigation Steps:**
1. Check SCADA device connectivity
2. Verify data collection service running
3. Check network between devices and GridOS
4. Review ingestion worker logs
5. Verify message queue (if used)

---

### 6. **GridOSHighMemoryUsage** (Warning)

**What it monitors:**
```promql
(sum(container_memory_working_set_bytes{namespace="gridos"})
 / sum(container_spec_memory_limit_bytes{namespace="gridos"})) > 0.9
```

**Meaning:** Memory usage >90% of limit

**Impact:**
- Risk of OOMKilled (pod termination)
- Performance degradation
- Potential data loss if pod killed

**Actions:**
- Review memory leaks in application
- Check if caching too much data
- Increase memory limits if necessary
- Enable memory profiling

---

### 7. **GridOSCPUThrottling** (Warning)

**What it monitors:**
```promql
rate(container_cpu_cfs_throttled_seconds_total{namespace="gridos"}[5m]) > 0.5
```

**Meaning:** CPU throttled >50% of the time

**Impact:**
- Slow request processing
- Increased latency
- Delayed SCADA data processing
- Backlog of alarms

**Actions:**
- Increase CPU limits
- Optimize CPU-intensive code
- Check for inefficient queries
- Consider horizontal scaling

---

### 8. **GridOSPodCrashLooping** (High)

**What it monitors:**
```promql
rate(kube_pod_container_status_restarts_total{namespace="gridos"}[15m]) > 0
```

**Meaning:** Pod restarting repeatedly

**Impact:**
- Service interruptions
- Data processing gaps
- Increased error rate
- User complaints

**Investigation:**
1. `kubectl logs <pod> --previous` (get crash logs)
2. Check for:
   - Uncaught exceptions
   - Database connection errors
   - Memory OOM errors
   - Configuration errors
3. Review recent code changes
4. Check resource limits

---

## 5. Additional Critical Alerts Needed

Let me add more essential alerts:

### 9. **GridOSDatabaseSlowQueries** (High)

```yaml
- alert: GridOSDatabaseSlowQueries
  expr: |
    histogram_quantile(0.95,
      rate(gridos_database_query_duration_seconds_bucket[5m])
    ) > 1.0
  for: 10m
  labels:
    severity: high
  annotations:
    summary: "Database queries are slow"
    description: "95th percentile query time is {{ $value }}s"
```

---

### 10. **GridOSHighDiskUsage** (Warning)

```yaml
- alert: GridOSHighDiskUsage
  expr: |
    (node_filesystem_size_bytes{mountpoint="/data"} 
     - node_filesystem_avail_bytes{mountpoint="/data"})
    / node_filesystem_size_bytes{mountpoint="/data"} * 100 > 85
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "Disk usage critical"
    description: "Disk {{ $labels.mountpoint }} is {{ $value }}% full"
```

---

### 11. **GridOSPersistentVolumeErrors** (Critical)

```yaml
- alert: GridOSPersistentVolumeErrors
  expr: |
    kube_persistentvolumeclaim_status_phase{
      namespace="gridos",
      phase!="Bound"
    } > 0
  for: 2m
  labels:
    severity: critical
  annotations:
    summary: "PVC not bound"
    description: "PVC {{ $labels.persistentvolumeclaim }} is {{ $labels.phase }}"
```

---

### 12. **GridOSCertificateExpiringSoon** (Warning)

```yaml
- alert: GridOSCertificateExpiringSoon
  expr: |
    (certmanager_certificate_expiration_timestamp_seconds
     - time()) / 86400 < 14
  for: 1h
  labels:
    severity: warning
  annotations:
    summary: "TLS certificate expiring soon"
    description: "Certificate {{ $labels.name }} expires in {{ $value }} days"
```

---

### 13. **GridOSSLOViolation** (Critical)

```yaml
- alert: GridOSSLOViolation
  expr: |
    (sum(rate(http_requests_total{app="gridos",status!~"5.."}[30d]))
     / sum(rate(http_requests_total{app="gridos"}[30d]))) < 0.999
  for: 5m
  labels:
    severity: critical
  annotations:
    summary: "SLO availability below target"
    description: "Availability is {{ $value | humanizePercentage }} (target: 99.9%)"
```

---

## 6. Complete Runbook List

### Automated Runbooks (Kubernetes Jobs)

1. **high-error-rate-rollback.yaml** ✅ Created
   - Auto-rollback on high error rate
   - Collects diagnostics
   - Posts to Slack

2. **database-connection-recovery.yaml** (TODO)
   - Restart app pods
   - Verify database health
   - Check connection pool

3. **scada-ingestion-restart.yaml** (TODO)
   - Restart data collection workers
   - Check device connectivity
   - Verify message queue

4. **pod-crashloop-debug.yaml** (TODO)
   - Collect crash logs
   - Check recent config changes
   - Verify resource limits

5. **scale-up-on-load.yaml** (TODO)
   - Auto-scale replicas
   - Monitor performance
   - Scale back when load decreases

6. **certificate-renewal.yaml** (TODO)
   - Trigger cert-manager renewal
   - Verify certificate valid
   - Restart affected pods

---

## 7. Interview Talking Points

### Question: "How does your observability stack work?"

**Answer:**
"We use Prometheus Operator deployed via Helm inside our Kubernetes cluster. Prometheus scrapes metrics from our GridOS SCADA application pods every 30 seconds by discovering pods with the `prometheus.io/scrape` annotation. These metrics are stored in a time-series database with 7-day retention in dev and 30-day in production.

Grafana queries Prometheus for metrics and Loki for logs to display on our dashboards. We have 4 dashboards: System Overview, SLO Tracking, Cluster Health, and Node Metrics.

AlertManager routes alerts based on severity—critical alerts go to PagerDuty to page the on-call engineer, high severity goes to Slack, and warnings are logged for review. We also have automated runbooks that can automatically rollback deployments if error rates spike after a deployment."

---

### Question: "What metrics do you collect?"

**Answer:**
"We collect four categories of metrics:

1. **Application metrics**: HTTP request rates, error rates, p95 latency, and endpoint-specific performance
2. **SCADA-specific metrics**: Data ingestion rates, active devices, alarm breaches, and processing lag
3. **Infrastructure metrics**: Pod CPU/memory usage, restart counts, node health, and disk usage
4. **Database metrics**: Connection pool stats, query performance, and error rates

These metrics help us maintain our SLO of 99.9% availability and sub-300ms p95 latency in production."

---

### Question: "How do you handle incidents?"

**Answer:**
"We have three tiers of incident response:

**Tier 1: Automated runbooks** for common issues like high error rates. If a deployment causes errors >2%, our runbook automatically rolls back the deployment, verifies the fix, and posts results to Slack—all within 2-3 minutes.

**Tier 2: Manual playbooks** for complex issues like database problems. AlertManager pages the on-call engineer via PagerDuty, and they follow documented runbooks with step-by-step remediation.

**Tier 3: Escalation** for critical outages. We have escalation policies in PagerDuty that page the team lead if the primary on-call doesn't respond within 5 minutes.

All incidents are tracked in our #gridos-incidents Slack channel with timestamps, actions taken, and post-incident reviews."

---

### Question: "Why Prometheus instead of other monitoring tools?"

**Answer:**
"Prometheus is ideal for Kubernetes environments because:

1. **Native Kubernetes integration**: Automatic service discovery via K8s API
2. **Pull-based model**: Prometheus scrapes targets, so apps don't need to know where to send metrics
3. **Powerful query language**: PromQL lets us calculate complex metrics like error rates and percentiles
4. **Industry standard**: Widely adopted with strong community support
5. **GitOps friendly**: Configuration managed in YAML via Helm values

We also integrated Loki for logs because it uses the same label-based approach as Prometheus, making it easy to correlate metrics and logs in Grafana."

---

## Summary

✅ **Prometheus scrapes metrics** from GridOS pods (HTTP, SCADA, database)  
✅ **Loki collects logs** from all containers  
✅ **Grafana visualizes** metrics and logs in dashboards  
✅ **AlertManager routes alerts** to Slack and PagerDuty  
✅ **Automated runbooks** handle common incidents  
✅ **13 critical alerts** covering app, infrastructure, and business metrics  
✅ **GitOps managed** via Argo CD with Helm charts  

This provides **complete observability** with **automated incident response** for production-grade SCADA monitoring.
