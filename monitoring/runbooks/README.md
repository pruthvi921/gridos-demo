# GridOS Incident Automation Runbooks

This directory contains automated runbooks that are triggered by AlertManager when specific alerts fire.

## Overview

When an alert fires in Prometheus, AlertManager can trigger automated remediation actions via:
1. **Kubernetes Jobs** - Run automated fix scripts
2. **Argo Workflows** - Complex multi-step remediation
3. **Webhook receivers** - Trigger external automation (Azure Automation, Lambda, etc.)

## Available Runbooks

### 1. High Error Rate (`gridos-high-error-rate.yaml`)
**Trigger:** Error rate > 5% for 5 minutes
**Actions:**
- Collect pod logs for last 30 minutes
- Check database connection status
- Analyze recent deployments
- Trigger canary rollback if recent deployment
- Send diagnostic bundle to Slack

### 2. Database Connection Failed (`gridos-db-connection.yaml`)
**Trigger:** Database connection errors detected
**Actions:**
- Check PostgreSQL pod status
- Verify connection string in secrets
- Test database connectivity from debug pod
- Restart application pods if needed
- Scale up database if resource constrained

### 3. SCADA Ingestion Stopped (`gridos-ingestion-stopped.yaml`)
**Trigger:** No SCADA readings for 10 minutes
**Actions:**
- Check SCADA data source connectivity
- Verify message queue status
- Restart ingestion pods
- Alert grid operators via PagerDuty
- Failover to backup ingestion endpoint

### 4. Pod Crash Loop (`gridos-pod-crashloop.yaml`)
**Trigger:** Pod restarting frequently
**Actions:**
- Collect crash logs
- Check resource limits (OOM kills)
- Verify ConfigMap/Secret mounts
- Roll back to previous stable version
- Create incident ticket automatically

### 5. High Memory Usage (`gridos-high-memory.yaml`)
**Trigger:** Memory usage > 90% for 5 minutes
**Actions:**
- Trigger memory heap dump
- Scale out pods horizontally
- Check for memory leaks
- Restart pod if memory leak detected

### 6. API Completely Down (`gridos-api-down.yaml`)
**Trigger:** All pods unreachable
**Actions:**
- Page on-call engineer immediately
- Check AKS node health
- Verify ingress controller status
- Scale up deployment replicas
- Failover to DR region if needed

## Runbook Execution Flow

```
Alert Fires in Prometheus
    ↓
AlertManager receives alert
    ↓
AlertManager sends webhook to automation service
    ↓
Kubernetes Job/Argo Workflow triggered
    ↓
Runbook executes automated steps
    ↓
Results posted to Slack + logged to Elasticsearch
    ↓
If automation fails → Page on-call engineer
```

## Creating New Runbooks

### Runbook Template

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: runbook-<alert-name>
  namespace: monitoring
spec:
  template:
    spec:
      serviceAccountName: runbook-executor
      containers:
      - name: remediation
        image: gridosacr.azurecr.io/runbook-executor:latest
        env:
        - name: ALERT_NAME
          value: "{{ .GroupLabels.alertname }}"
        - name: SEVERITY
          value: "{{ .CommonLabels.severity }}"
        command:
        - /bin/sh
        - -c
        - |
          # Your remediation logic here
          echo "Running automated remediation for $ALERT_NAME"
          
          # Example: Restart pods
          kubectl rollout restart deployment/gridos -n gridos
          
          # Post results to Slack
          curl -X POST $SLACK_WEBHOOK \
            -H 'Content-Type: application/json' \
            -d '{"text":"Automated remediation completed for '"$ALERT_NAME"'"}'
      restartPolicy: Never
  backoffLimit: 3
```

## Best Practices

1. **Idempotency**: Runbooks should be safe to run multiple times
2. **Logging**: Always log actions taken for audit trail
3. **Rollback**: Have undo steps for all actions
4. **Testing**: Test runbooks in dev before prod
5. **Timeouts**: Set reasonable timeouts (5-10 minutes max)
6. **Notifications**: Always notify team of automated actions
7. **Human approval**: Critical actions should require approval

## Safety Mechanisms

- **Rate limiting**: Max 3 runbook executions per hour per alert
- **Dry-run mode**: Test runbooks without making changes
- **Manual override**: On-call can disable automation
- **Blast radius limits**: Can't scale beyond safe limits
- **Audit log**: All actions logged to Elasticsearch

## Monitoring Runbooks

Dashboard: `https://grafana.gridos.example.com/d/runbooks`

Metrics:
- `runbook_executions_total{runbook, status}`
- `runbook_duration_seconds{runbook}`
- `runbook_success_rate{runbook}`

## Example: Automated Rollback Runbook

See `examples/rollback-on-high-errors.yaml` for a complete example that:
1. Detects high error rate after deployment
2. Checks if deployment happened in last 30 minutes
3. Automatically rolls back to previous version
4. Verifies error rate returns to normal
5. Posts incident report to Slack
