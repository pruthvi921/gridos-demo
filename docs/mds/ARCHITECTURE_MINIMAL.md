# GridOS Minimal Architecture (Interview Ready)

Purpose: Concise version without Azure Front Door or optional addons (service mesh, multi-region, tracing, chaos). Focus on core GitOps, delivery, and observability path.

## 1. Component Stack (Mandatory Only)

| Layer | Component | Responsibility |
|-------|-----------|----------------|
| Infra Provisioning | Terraform | Azure resource creation (RG, VNet, AKS, ACR, DB, Key Vault, App Gateway) |
| Image Build & Scan | GitHub Actions (CI) | Build Docker, run tests, security/coverage, push image to ACR |
| Source of Truth | Git (manifests + tags) | Desired cluster/application configuration |
| Deployment Orchestrator | Argo CD | Reconcile cluster state with Git (continuous) |
| Progressive Delivery | Argo Rollouts | Canary steps + analysis + rollback |
| Runtime Platform | AKS | Execute workloads (pods, services, ingress) |
| Ingress / Edge | Azure Application Gateway (AGIC) | WAF, TLS termination, path/host routing into cluster |
| Registry | ACR | Container image storage |
| Secrets | Key Vault + CSI/ESO | Secure, externalized secret management |
| Observability | Prometheus / Alertmanager / Grafana / Loki | Metrics, alerts, dashboards, logs |

## 2. High-Level Flow

```
 Developer Commit
      ↓
 GitHub Actions (build, test, scan, push image)
      ↓
 Kustomize overlay image tag update (Git commit)
      ↓
 Argo CD detects Git change → sync to AKS
      ↓
 Argo Rollouts starts canary (10% → 25% → 50% → 100%)
      ↓
 Prometheus monitors canary metrics (error rate, latency, saturation)
      ↓
 Alertmanager triggers rollback if analysis fails
      ↓
 Stable version promoted / rollback executed
```

## 3. ASCII Architecture Diagram (Simplified)

```
            +----------------------+
            |      Developers      |
            +----------+-----------+
                       | Commit / PR
                       v
                +-------------+
                |   GitHub    |
                |  Actions CI |
                +------+------+ 
                       | Push Image / Patch Manifest
                       v
            +----------------------+      +------------------+
            |        Git Repo      | ---> |  Argo CD (Sync)  |
            +----------------------+      +---------+--------+
                                                  |
                                                  v
                                        +------------------+
                                        |  AKS Cluster     |
                                        | (Deployments,    |
                                        |  Services, HPA)  |
                                        +---+---------+----+
                                            |         |
                              +-------------v--+   +--v--------------+
                              | Argo Rollouts  |   | App Gateway (AGIC)|
                              | Canary Steps   |   | Ingress/WAF/TLS   |
                              +-------+--------+   +--------+---------+
                                      | (Traffic via Service)
                                      v
                                 +---------+
                                 |  Pods   |
                                 +----+----+
                                      |
                     +----------------v------------------+
                     |   Prometheus / Grafana / Loki     |
                     |   (Metrics, Dashboards, Logs)     |
                     +----------------+------------------+
                                      |
                                      v
                               +-------------+
                               | Alertmanager|
                               +------+------+ 
                                      |
                                      v
                               +-------------+
                               |  On-Call    |
                               |  Runbooks   |
                               +-------------+
```

## 4. Canary Delivery (Mandatory Signals)

Steps (example): 10% (1 min) → 25% (2 min) → 50% (3 min) → 100%. After each step an AnalysisTemplate queries Prometheus:

| Metric | Query Pattern | Threshold | Action |
|--------|---------------|-----------|--------|
| Error Rate | `sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m]))` | < 1% | Proceed / rollback |
| p95 Latency | `histogram_quantile(0.95, sum(rate(request_duration_seconds_bucket[5m])) by (le))` | < 250ms | Proceed / rollback |
| Saturation (CPU) | `avg(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate{namespace="gridos"})` | < 70% | Proceed / tune |

If any metric violates threshold → rollback to previous stable version automatically.

## 5. Rollback Paths

1. Automated: Argo Rollouts analysis failure.
2. Declarative: `git revert` manifest commit → Argo CD syncs old state.
3. Manual: `kubectl argo rollouts undo rollout gridos -n gridos`.

## 6. Security (Minimal Set)

| Control | Implementation |
|---------|----------------|
| Secrets | Key Vault + CSI driver, never in Git |
| Auth for CI | GitHub OIDC federated credential to Azure (no static SP secret) |
| Image Integrity | Vulnerability scan (Snyk/Trivy) in CI gate |
| Network Edge | App Gateway WAF + TLS termination |
| Least Privilege | Managed Identity for pod access to Key Vault/DB |

## 7. SLO & Error Budget (Example)

Service SLO: Availability 99.9% monthly.
Monthly minutes ≈ 43,200 → Error budget ≈ 43.2 minutes.
Burn tracking: Prometheus recording rule compares downtime/5xx ratio against budget remainder; alert at 50% burn.

## 8. Interview Pitch (Minimal Version)

"GridOS uses a clean GitOps pipeline: Terraform provisions Azure (AKS, networking, App Gateway, ACR, Key Vault). CI builds, tests, scans, and pushes images; updates Kustomize overlays. Argo CD syncs manifests; Argo Rollouts performs canary steps with Prometheus-based checks (error rate, latency, saturation) and auto rollback. Secrets sit in Key Vault, ingress and WAF via Application Gateway, everything is declarative and observable (Prometheus/Grafana/Loki). Rollbacks are one command or Git revert—fast, auditable, and reliable." 

## 9. Why This Minimal Set is Strong

| Goal | Achieved By |
|------|-------------|
| Fast Safe Releases | Canary + automated analysis |
| Auditability | Git-driven manifests, image digests |
| Security Baseline | Key Vault, OIDC, scans |
| Observability | Unified metrics/logs + alerting |
| Low Complexity | Avoids multi-region, service mesh, and edge global layers initially |

## 10. Next Natural Enhancements (Mention Only If Asked)

- Service mesh (Istio) for retries/mTLS and precise traffic weighting.
- Global routing / multi-region with Azure Front Door.
- Tracing (OpenTelemetry + Tempo) for deep latency analysis.
- Policy enforcement (OPA/Gatekeeper) for compliance.
- Chaos experiments for resilience validation.

---

Use this as a succinct reference; it deliberately omits optional layers per request.
