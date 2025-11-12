# On-Call Procedures

**Team:** GridOS SRE  
**Last Updated:** 2024-11-10  
**Version:** 1.0

---

## On-Call Schedule

### Rotation

- **Primary On-Call:** 1-week rotation
- **Secondary On-Call:** 1-week rotation (backup)
- **Rotation Schedule:** PagerDuty
- **Handoff Time:** Monday 10:00 AM CET

### On-Call Responsibilities

**Primary On-Call:**
- First responder to all alerts
- Incident management and coordination
- Customer communication (via status page)
- Post-incident documentation

**Secondary On-Call:**
- Backup if primary doesn't respond within 15 minutes
- Support for complex incidents
- Escalation point

---

## Before Your Shift

### 48 Hours Before

- [ ] Review upcoming change calendar
- [ ] Check known issues in #sre-incidents
- [ ] Review recent postmortems
- [ ] Test PagerDuty notification delivery
- [ ] Ensure laptop and phone are charged

### Handoff Meeting (30 minutes)

**Agenda:**
1. Active incidents (5 min)
2. Ongoing issues (5 min)
3. Upcoming changes/deployments (5 min)
4. Recent alerts and patterns (5 min)
5. Questions and concerns (10 min)

**Handoff Template:**
```markdown
## On-Call Handoff - [Date]

### Active Incidents
- None / [INC-XXXX]: Brief description

### Watch Items
- Item 1: Description, what to monitor
- Item 2: Description, when to escalate

### Upcoming Changes
- [Date/Time]: Change description, risk level

### Recent Trends
- Alert frequency changes
- Performance degradation
- Resource usage patterns

### Action Items
- [ ] Task 1
- [ ] Task 2

### Notes
- Any additional context
```

---

## During Your Shift

### Alert Response Protocol

#### Step 1: Acknowledge (Within 5 minutes)

```bash
# In PagerDuty mobile app or web:
# 1. Click "Acknowledge"
# 2. Add note: "Investigating"
```

#### Step 2: Assess Severity (Within 10 minutes)

**SEV-1 (Critical):**
- Complete service outage
- Data loss or corruption
- Security breach
- Affects > 50% of users

**SEV-2 (High):**
- Partial service degradation
- Affects specific feature/region
- SLO threatened
- Affects 10-50% of users

**SEV-3 (Medium):**
- Minor degradation
- Non-critical functionality impaired
- SLO still met
- Affects < 10% of users

**SEV-4 (Low):**
- Informational
- No user impact
- Planned work

#### Step 3: Investigate

Use appropriate runbook:
- [High Error Rate](../runbooks/high-error-rate.md)
- [Service Down](../runbooks/service-down.md)
- [High Latency](../runbooks/high-latency.md)
- [Database Issues](../runbooks/database-issues.md)

```bash
# Quick diagnostic script
./scripts/incident-response/collect-diagnostics.sh

# Check Grafana
open https://grafana.example.com/d/gridos-overview
```

#### Step 4: Communicate

**For SEV-1 & SEV-2:**

*Initial Update (within 15 min):*
```
🚨 [SEV-X] INCIDENT: Brief description

Status: Investigating
Impact: [Description]
Started: [Time] UTC
Team: Investigating now
Next Update: [Time + 15 min]

Status Page: https://status.gridos.example.com
```

*Regular Updates (every 15-30 min):*
```
⚡ UPDATE: Incident title

Status: [Investigating/Mitigating/Monitoring]
Progress: [What we've found/done]
Impact: [Current status]
Next Update: [Time]
```

*Resolution:*
```
✅ RESOLVED: Incident title

Root Cause: [Brief description]
Resolution: [What fixed it]
Duration: [Total time]
Impact: [Summary]

Postmortem: [Link when available]
```

**Communication Channels:**
- Slack: #incidents (all severities)
- Status Page: SEV-1 & SEV-2 only
- Email: Leadership (SEV-1 only)
- Customer notifications: Via status page

#### Step 5: Mitigate

Follow runbook procedures. Common actions:

```bash
# Rollback deployment
kubectl rollout undo deployment/gridos-api -n gridos

# Scale up
kubectl scale deployment/gridos-api -n gridos --replicas=6

# Restart pods
kubectl rollout restart deployment/gridos-api -n gridos

# Check logs
kubectl logs -n gridos -l app=gridos --tail=100

# Failover database
./scripts/incident-response/database-failover.sh
```

#### Step 6: Resolve & Document

- Update all communication channels
- Create Jira ticket for follow-up
- Schedule postmortem (SEV-1 & SEV-2)
- Update runbook if needed
- Thank responders

---

## Escalation Paths

### When to Escalate

**Immediately Escalate For:**
- Unable to mitigate within 30 minutes
- Security incident suspected
- Data loss detected
- Need specialized knowledge
- Unclear how to proceed

**Don't Hesitate to Escalate!**
It's better to escalate early than let an incident grow.

### Escalation Tree

```
You (Primary On-Call)
    ↓
Secondary On-Call
    ↓
SRE Team Lead
    ↓
Engineering Manager
    ↓
Director of Engineering
    ↓
CTO
```

### Subject Matter Experts

| Area | Contact | Slack |
|------|---------|-------|
| Database | @db-team | #db-guild |
| Kubernetes | @k8s-experts | #kubernetes |
| Networking | @network-team | #networking |
| Security | @security-team | #security-incidents |
| Frontend | @frontend-team | #frontend |
| Backend | @backend-team | #backend |

### External Escalations

| Vendor | Contact Method | SLA |
|--------|----------------|-----|
| Azure Support | Portal + Phone | 1 hour (Severity A) |
| Database Vendor | Email + Phone | 2 hours |
| Network Provider | Phone | 30 minutes |

---

## Common Scenarios

### Scenario 1: Alert During Business Hours

✅ **DO:**
- Acknowledge immediately
- Post in #incidents
- Follow runbook
- Communicate clearly

❌ **DON'T:**
- Ignore or silence alerts
- Investigate alone if complex
- Forget to communicate

### Scenario 2: Alert at 3 AM

✅ **DO:**
- Acknowledge within 5 minutes
- Assess if it can wait until morning
- Mitigate if SEV-1 or SEV-2
- Document what happened
- Get rest after resolution

❌ **DON'T:**
- Make risky changes when tired
- Skip documentation
- Hesitate to escalate

### Scenario 3: Multiple Simultaneous Alerts

✅ **DO:**
- Triage by severity and impact
- Acknowledge all alerts
- Call secondary on-call for help
- Focus on highest impact first
- Look for common root cause

❌ **DON'T:**
- Try to handle all at once alone
- Panic
- Ignore any alerts

### Scenario 4: Customer Reports Issue, No Alerts

✅ **DO:**
- Thank customer for reporting
- Create incident ticket
- Investigate manually
- Check if monitoring gap exists
- Follow up with customer

❌ **DON'T:**
- Dismiss as user error
- Wait for alerts
- Forget to close loop

---

## Tools and Access

### Required Access

- [ ] PagerDuty admin access
- [ ] Kubernetes cluster admin
- [ ] Azure portal contributor
- [ ] Grafana admin
- [ ] Slack admin (for #incidents)
- [ ] Status page editor
- [ ] VPN credentials
- [ ] SSH keys configured

### Essential Links

- **Runbooks:** https://github.com/org/gridos/tree/main/docs/runbooks
- **Grafana:** https://grafana.example.com
- **Prometheus:** https://prometheus.example.com
- **Status Page:** https://status.gridos.example.com
- **PagerDuty:** https://yourorg.pagerduty.com
- **Incident Tracker:** https://jira.example.com/projects/INC

### Quick Commands

```bash
# Get kubeconfig
az aks get-credentials --resource-group dev-gridos-rg --name dev-gridos-aks

# Port forward to services
kubectl port-forward svc/grafana 3000:80 -n monitoring
kubectl port-forward svc/prometheus 9090:9090 -n monitoring

# Check pod status
kubectl get pods -n gridos -o wide

# Tail logs
kubectl logs -n gridos -l app=gridos --follow --tail=100

# Run diagnostic script
./scripts/incident-response/collect-diagnostics.sh
```

---

## Shift End

### End-of-Shift Checklist

- [ ] Resolve or hand off any active incidents
- [ ] Document all actions taken
- [ ] Update known issues list
- [ ] Schedule handoff meeting with next on-call
- [ ] Submit any necessary follow-up tickets
- [ ] Update runbooks if gaps found

### Shift Report Template

```markdown
## On-Call Shift Report - [Date Range]

### Incident Summary
- Total incidents: X
- SEV-1: X | SEV-2: X | SEV-3: X | SEV-4: X
- MTTR: X minutes average

### Notable Incidents
1. [INC-XXXX]: Description, resolution
2. [INC-YYYY]: Description, resolution

### Alert Statistics
- Total alerts: X
- False positives: X
- Auto-resolved: X

### Actions Taken
- Deployment rollbacks: X
- Manual interventions: X
- Escalations: X

### Improvements Needed
- Alert tuning needed for: X
- Runbook updates needed for: Y
- Tooling gaps: Z

### Handoff Notes
[Notes for next on-call]
```

---

## Support and Resources

### If You Need Help

- **Urgent:** Call secondary on-call
- **Questions:** #sre-team Slack channel
- **Advice:** #sre-oncall Slack channel
- **Mental Health:** Employee Assistance Program

### Remember

- **You're not alone:** The team is here to support you
- **Escalate early:** Better safe than sorry
- **Document everything:** Future you will thank you
- **Take breaks:** Especially during long incidents
- **It's okay to not know:** That's what escalation is for

### After a Tough Shift

- Decompress with the team
- Write up the experience
- Propose improvements
- Take time off if needed
- Remember: Systems fail, people learn

---

## On-Call Compensation

- **Stipend:** $X per week on-call
- **Overtime:** Time-and-a-half for after-hours work > 1 hour
- **Comp Time:** Available after major incidents
- **Incident Bonus:** For SEV-1 incidents resolved

---

## Feedback and Improvements

We continuously improve our on-call experience:

- Monthly on-call retros
- Runbook updates after each incident
- Alert tuning based on feedback
- Tool improvements

**Submit feedback:** #sre-oncall-feedback

---

## Emergency Contacts

### Critical Escalations

- **Security Incident:** security-oncall@example.com | +47 XXX XX XXX
- **Data Privacy:** dpo@example.com
- **Legal:** legal-urgent@example.com
- **PR/Communications:** pr@example.com

### Vendor Support

- **Azure Premier Support:** +1-XXX-XXX-XXXX (24/7)
- **Database Vendor:** support@vendor.com | +47 XXX XX XXX
- **Network Provider:** +47 XXX XX XXX

---

*"Being on-call is a team responsibility. We support each other through incidents and continuously improve our systems and processes."* - SRE Team
