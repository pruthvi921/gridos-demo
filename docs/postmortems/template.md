# Incident Postmortem Template

**Incident ID:** INC-YYYY-XXXX  
**Date:** YYYY-MM-DD  
**Authors:** [Names]  
**Status:** Draft | Under Review | Published

---

## Executive Summary

*Brief 2-3 sentence summary of what happened, the impact, and the resolution.*

---

## Incident Details

### Timeline

| Time (UTC) | Event |
|------------|-------|
| HH:MM | [First symptom/alert detected] |
| HH:MM | [Investigation began] |
| HH:MM | [Root cause identified] |
| HH:MM | [Mitigation applied] |
| HH:MM | [Service restored] |
| HH:MM | [Incident closed] |

**Total Duration:** X hours, Y minutes  
**Time to Detect (TTD):** X minutes  
**Time to Mitigate (TTM):** Y minutes  

### Impact Assessment

**Severity:** Critical | High | Medium | Low  
**Affected Services:** 
- Service A
- Service B

**User Impact:**
- Number of affected users: X
- Failed requests: X (Y%)
- Lost transactions: X
- Geographic scope: [Regions affected]

**Business Impact:**
- Revenue impact: $X estimated
- SLO status: [In budget | Budget exhausted]
- Customer complaints: X
- Support tickets: X

### SLO Impact

| SLO | Target | Actual | Budget Consumed |
|-----|--------|--------|-----------------|
| Availability | 99.9% | 99.X% | X% |
| Latency (p95) | <200ms | Xms | X% |
| Error Rate | <0.1% | X% | X% |

---

## Root Cause Analysis

### What Happened

*Detailed explanation of what went wrong. Include:*
- Initial trigger/event
- Cascade of failures
- Why systems didn't handle it gracefully
- Why monitoring didn't catch it sooner (if applicable)

### Root Cause

*Single, specific root cause. Use 5 Whys if helpful:*

1. Why did X happen? Because Y
2. Why did Y happen? Because Z
3. [Continue until root cause found]

**Root Cause:** [Clear statement of the fundamental issue]

### Contributing Factors

*List other factors that made the incident worse or prevented quick resolution:*

1. Factor 1: Description
2. Factor 2: Description
3. Factor 3: Description

---

## Detection and Response

### What Went Well

- ✅ Detection: [How it was detected]
- ✅ Response time: [Speed of response]
- ✅ Communication: [Internal/external]
- ✅ Mitigation: [Effective actions]

### What Went Poorly

- ❌ Delayed detection: [Gaps in monitoring]
- ❌ Unclear runbook: [Documentation issues]
- ❌ Manual steps: [Lack of automation]
- ❌ Communication gaps: [Who wasn't informed]

---

## Action Items

### Immediate Actions (Completed During Incident)

- [x] Action 1 - Owner: @person - Completed: YYYY-MM-DD
- [x] Action 2 - Owner: @person - Completed: YYYY-MM-DD

### Prevent Recurrence

| Action | Owner | Priority | Due Date | Status |
|--------|-------|----------|----------|--------|
| Add monitoring for X | @engineer1 | P0 | YYYY-MM-DD | In Progress |
| Implement circuit breaker | @engineer2 | P0 | YYYY-MM-DD | Not Started |
| Update runbook with findings | @sre1 | P1 | YYYY-MM-DD | Not Started |
| Add automated rollback | @engineer3 | P1 | YYYY-MM-DD | Not Started |

### Improve Detection

| Action | Owner | Priority | Due Date | Status |
|--------|-------|----------|----------|--------|
| Add alert for Y condition | @sre1 | P0 | YYYY-MM-DD | Not Started |
| Improve alert signal-to-noise | @sre2 | P1 | YYYY-MM-DD | Not Started |
| Dashboard enhancements | @sre3 | P2 | YYYY-MM-DD | Not Started |

### Improve Response

| Action | Owner | Priority | Due Date | Status |
|--------|-------|----------|----------|--------|
| Create runbook for X | @sre1 | P0 | YYYY-MM-DD | Not Started |
| Automate mitigation script | @engineer1 | P1 | YYYY-MM-DD | Not Started |
| Conduct fire drill | @sre-lead | P1 | YYYY-MM-DD | Not Started |

### Process Improvements

| Action | Owner | Priority | Due Date | Status |
|--------|-------|----------|----------|--------|
| Update deployment checklist | @devops1 | P1 | YYYY-MM-DD | Not Started |
| Improve communication protocol | @manager1 | P2 | YYYY-MM-DD | Not Started |
| Schedule chaos engineering exercise | @sre-lead | P2 | YYYY-MM-DD | Not Started |

---

## Lessons Learned

### Technical Lessons

1. **Lesson 1:** Description of what we learned about our systems
2. **Lesson 2:** Insight about architecture, design, or implementation
3. **Lesson 3:** Understanding of failure modes

### Process Lessons

1. **Lesson 1:** What we learned about incident response
2. **Lesson 2:** Insights about communication or coordination
3. **Lesson 3:** Understanding of gaps in procedures

### Organizational Lessons

1. **Lesson 1:** Insights about team structure or roles
2. **Lesson 2:** Understanding of skill gaps or training needs
3. **Lesson 3:** Knowledge about documentation or knowledge sharing

---

## Supporting Information

### Related Incidents

- [INC-YYYY-XXXX](link) - Similar issue in DATE
- [INC-YYYY-YYYY](link) - Related component failure

### Relevant Documents

- [Architecture Diagram](link)
- [Runbook: High Error Rate](link)
- [Change Request: CR-XXXX](link)
- [Deployment Log](link)

### Metrics and Graphs

*Include screenshots or links to:*
- Error rate over time
- Request volume
- Resource utilization
- Latency metrics

### External Communication

*Links to or copies of:*
- Status page updates
- Customer notifications
- Social media posts

---

## Appendix

### Technical Details

*Detailed technical information:*
- Stack traces
- Log excerpts
- Configuration changes
- Database queries
- Network diagnostics

### Commands Used

```bash
# Investigation commands
kubectl get pods -n gridos
kubectl logs pod-name -n gridos

# Mitigation commands  
kubectl rollout undo deployment/gridos-api -n gridos
kubectl scale deployment/gridos-api --replicas=6
```

### People Involved

| Role | Name | Actions |
|------|------|---------|
| Incident Commander | @person1 | Led response |
| On-Call Engineer | @person2 | Initial investigation |
| Database Expert | @person3 | Database analysis |
| Engineering Lead | @person4 | Decision making |

---

## Sign-off

**Reviewed By:**
- [ ] Engineering Lead: @person - Date:
- [ ] SRE Lead: @person - Date:
- [ ] Product Manager: @person - Date:

**Approved By:**
- [ ] Director of Engineering: @person - Date:

---

## Follow-up

**Follow-up Meeting:** YYYY-MM-DD HH:MM UTC  
**Attendees:** [List]  
**Agenda:**
1. Review action items
2. Discuss implementation challenges
3. Update timelines if needed

**Next Review:** YYYY-MM-DD

---

*This postmortem follows the blameless postmortem culture. The goal is learning and improvement, not assigning blame.*
