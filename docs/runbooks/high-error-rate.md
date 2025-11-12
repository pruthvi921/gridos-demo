# Runbook: High Error Rate Alert

**Alert Name:** HighErrorRate  
**Severity:** Critical  
**SLO Impact:** Availability  
**Last Updated:** 2024-11-10

## Alert Description

This alert fires when the HTTP 5xx error rate exceeds 1% over a 5-minute window, indicating potential service degradation affecting user experience.

## Impact

- **User Impact:** HIGH - Users experiencing failed requests
- **Business Impact:** Service unavailability affects grid monitoring capabilities
- **SLO Impact:** Threatens 99.9% availability target

## Triage Steps

### 1. Verify the Alert (2 minutes)

```bash
# Check current error rate
kubectl port-forward svc/prometheus 9090:9090 -n monitoring &
open http://localhost:9090/graph?g0.expr=sum(rate(http_requests_total{job="gridos-api",status=~"5.."}[5m]))%20%2F%20sum(rate(http_requests_total{job="gridos-api"}[5m]))%20*%20100

# Check Grafana dashboard
open https://grafana.example.com/d/gridos-overview
```

### 2. Identify Error Patterns (3 minutes)

```bash
# Check pod status
kubectl get pods -n gridos

# View recent logs with errors
kubectl logs -n gridos -l app.kubernetes.io/name=gridos --tail=100 | grep -i error

# Check which endpoints are failing
kubectl logs -n gridos -l app.kubernetes.io/name=gridos --since=10m | \
  grep "status\":[45]" | jq -r '.path' | sort | uniq -c | sort -rn
```

### 3. Check Infrastructure Health (2 minutes)

```bash
# Check node health
kubectl top nodes

# Check pod resources
kubectl top pods -n gridos

# Check database connectivity
kubectl exec -n gridos deploy/gridos-api -- \
  curl -s localhost:8080/health | jq .
```

## Common Causes & Solutions

### Cause 1: Database Connection Issues

**Symptoms:**
- Errors mention "connection", "timeout", "PostgreSQL"
- Database health check failing

**Solution:**
```bash
# Check database status
az postgres flexible-server show \
  --resource-group dev-gridos-rg \
  --name dev-gridos-psql

# Check connection pool
kubectl logs -n gridos deploy/gridos-api | grep "connection pool"

# If pool exhausted, restart pods to reset connections
kubectl rollout restart deployment/gridos-api -n gridos
```

### Cause 2: Resource Exhaustion

**Symptoms:**
- OOMKilled events
- CPU throttling
- Slow response times

**Solution:**
```bash
# Check resource usage
kubectl describe pod -n gridos -l app.kubernetes.io/name=gridos

# Temporary: Scale up
kubectl scale deployment/gridos-api -n gridos --replicas=6

# Permanent: Update resource limits in values.yaml
```

### Cause 3: Upstream Service Failures

**Symptoms:**
- Specific endpoints failing
- Timeout errors
- External service mentioned in logs

**Solution:**
```bash
# Check external dependencies
kubectl exec -n gridos deploy/gridos-api -- curl -v https://external-api.example.com

# Implement circuit breaker or increase timeout
# Update configuration in ConfigMap
```

### Cause 4: Bad Deployment

**Symptoms:**
- Errors started after recent deployment
- New version showing in logs

**Solution:**
```bash
# Check deployment history
kubectl rollout history deployment/gridos-api -n gridos

# Rollback to previous version
kubectl rollout undo deployment/gridos-api -n gridos

# Monitor rollback progress
kubectl rollout status deployment/gridos-api -n gridos
```

### Cause 5: Database Query Performance

**Symptoms:**
- Slow queries in logs
- Database CPU high
- Timeout errors

**Solution:**
```bash
# Identify slow queries from logs
kubectl logs -n gridos deploy/gridos-api | \
  grep "duration" | awk '{print $NF}' | sort -n | tail -20

# Check database performance metrics
az monitor metrics list \
  --resource dev-gridos-psql \
  --metric-names "cpu_percent,memory_percent" \
  --start-time $(date -u -d '30 minutes ago' +%Y-%m-%dT%H:%M:%SZ)

# Consider: Adding indexes, query optimization, read replicas
```

## Escalation

### When to Escalate

- Error rate > 5% for > 10 minutes
- Multiple resolution attempts failed
- Business critical impact confirmed
- Database or infrastructure issues detected

### Escalation Contacts

1. **L2 On-Call:** #sre-oncall Slack channel
2. **Database Team:** db-oncall@example.com
3. **Engineering Lead:** +47 XXX XX XXX
4. **Incident Commander:** Use PagerDuty escalation

## Communication Templates

### Initial Notification

```
🚨 INCIDENT: High error rate on GridOS API

Status: Investigating
Impact: Users may experience failures accessing the grid monitoring system
Error Rate: X.X%
Started: HH:MM UTC

We're actively investigating and will provide updates every 15 minutes.
```

### Update Template

```
⚡ UPDATE: GridOS API error rate investigation

Current Status: [Investigating/Identified/Mitigating/Resolved]
Action Taken: [Brief description]
Next Steps: [What we're doing next]
Next Update: [Time]
```

### Resolution Template

```
✅ RESOLVED: GridOS API error rate back to normal

Root Cause: [Brief description]
Resolution: [What fixed it]
Duration: [Total incident time]
Impact: [Summary of user impact]

Full postmortem will be available within 48 hours.
```

## Prevention

### Short-term
- Increase resource limits if resource exhaustion
- Add connection pool monitoring alerts
- Implement retry logic with exponential backoff

### Long-term
- Regular load testing
- Chaos engineering exercises
- Database query optimization
- Connection pool tuning
- Circuit breaker implementation

## Related Runbooks

- [Service Down](./service-down.md)
- [High Latency](./high-latency.md)
- [Database Connection Pool Exhausted](./db-connection-pool.md)
- [Deployment Rollback](./deployment-rollback.md)

## Validation

After mitigation, verify:

```bash
# Error rate back to normal
# Check Prometheus/Grafana

# All pods healthy
kubectl get pods -n gridos

# Health checks passing
kubectl exec -n gridos deploy/gridos-api -- curl localhost:8080/health

# Sample requests successful
curl https://api.gridos.example.com/api/gridnodes
```

## Postmortem

Create postmortem using [template](../postmortems/template.md) within 48 hours if:
- Incident lasted > 30 minutes
- SLO was impacted
- User-facing impact occurred
- Multiple services affected

## Revision History

| Date       | Author | Changes |
|------------|--------|---------|
| 2024-11-10 | SRE Team | Initial version |
