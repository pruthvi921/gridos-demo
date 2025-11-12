#!/bin/bash
# Collect Comprehensive Diagnostics
# This script gathers logs, metrics, and system state for incident analysis

set -euo pipefail

NAMESPACE="${NAMESPACE:-gridos}"
OUTPUT_DIR="${OUTPUT_DIR:-/tmp/gridos-diagnostics-$(date +%Y%m%d-%H%M%S)}"
RESOURCE_GROUP="${RESOURCE_GROUP:-dev-gridos-rg}"
AKS_CLUSTER="${AKS_CLUSTER:-dev-gridos-aks}"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

create_output_dir() {
    mkdir -p "$OUTPUT_DIR"/{logs,metrics,manifests,events,database}
    log "Created output directory: $OUTPUT_DIR"
}

collect_cluster_info() {
    log "Collecting cluster information..."
    
    kubectl cluster-info > "$OUTPUT_DIR/cluster-info.txt" 2>&1
    kubectl version > "$OUTPUT_DIR/version.txt" 2>&1
    kubectl get nodes -o wide > "$OUTPUT_DIR/nodes.txt" 2>&1
    kubectl top nodes > "$OUTPUT_DIR/nodes-usage.txt" 2>&1
}

collect_namespace_resources() {
    log "Collecting namespace resources..."
    
    for resource in pods deployments services configmaps secrets hpa ingress pvc; do
        kubectl get "$resource" -n "$NAMESPACE" -o yaml > "$OUTPUT_DIR/manifests/${resource}.yaml" 2>&1
        kubectl get "$resource" -n "$NAMESPACE" -o wide > "$OUTPUT_DIR/${resource}.txt" 2>&1
    done
}

collect_pod_logs() {
    log "Collecting pod logs..."
    
    kubectl get pods -n "$NAMESPACE" -o name | while read pod; do
        pod_name=$(basename "$pod")
        log "Collecting logs for $pod_name"
        
        # Current logs
        kubectl logs "$pod" -n "$NAMESPACE" --all-containers=true \
            > "$OUTPUT_DIR/logs/${pod_name}.log" 2>&1
        
        # Previous logs (if pod restarted)
        kubectl logs "$pod" -n "$NAMESPACE" --previous --all-containers=true \
            > "$OUTPUT_DIR/logs/${pod_name}-previous.log" 2>&1 || true
        
        # Pod description
        kubectl describe "$pod" -n "$NAMESPACE" \
            > "$OUTPUT_DIR/logs/${pod_name}-describe.txt" 2>&1
    done
}

collect_events() {
    log "Collecting events..."
    
    kubectl get events -n "$NAMESPACE" --sort-by='.lastTimestamp' \
        > "$OUTPUT_DIR/events/namespace-events.txt" 2>&1
    
    kubectl get events --all-namespaces --sort-by='.lastTimestamp' \
        > "$OUTPUT_DIR/events/all-events.txt" 2>&1
}

collect_metrics() {
    log "Collecting metrics..."
    
    # Pod metrics
    kubectl top pods -n "$NAMESPACE" > "$OUTPUT_DIR/metrics/pod-metrics.txt" 2>&1 || true
    
    # Prometheus metrics snapshot (if available)
    if kubectl get svc prometheus -n monitoring &>/dev/null; then
        kubectl port-forward svc/prometheus 9090:9090 -n monitoring &
        PF_PID=$!
        sleep 3
        
        # Collect key metrics
        curl -s "http://localhost:9090/api/v1/query?query=up" \
            > "$OUTPUT_DIR/metrics/prometheus-up.json" 2>&1 || true
        
        curl -s "http://localhost:9090/api/v1/query?query=http_requests_total" \
            > "$OUTPUT_DIR/metrics/prometheus-requests.json" 2>&1 || true
        
        kill $PF_PID 2>/dev/null || true
    fi
}

collect_database_info() {
    log "Collecting database information..."
    
    # Get PostgreSQL server info from Azure
    if command -v az &>/dev/null; then
        az postgres flexible-server show \
            --resource-group "$RESOURCE_GROUP" \
            --name "dev-gridos-psql" \
            > "$OUTPUT_DIR/database/server-info.json" 2>&1 || true
        
        az postgres flexible-server list-skus \
            --location norwayeast \
            > "$OUTPUT_DIR/database/available-skus.json" 2>&1 || true
    fi
}

collect_network_info() {
    log "Collecting network information..."
    
    # Network policies
    kubectl get networkpolicies -n "$NAMESPACE" -o yaml \
        > "$OUTPUT_DIR/manifests/network-policies.yaml" 2>&1 || true
    
    # Services and endpoints
    kubectl get endpoints -n "$NAMESPACE" -o wide \
        > "$OUTPUT_DIR/endpoints.txt" 2>&1
}

create_summary() {
    log "Creating diagnostic summary..."
    
    cat > "$OUTPUT_DIR/SUMMARY.md" <<EOF
# GridOS Diagnostic Report
Generated: $(date)
Namespace: $NAMESPACE
Cluster: $AKS_CLUSTER

## Quick Stats
- Pods: $(kubectl get pods -n "$NAMESPACE" --no-headers | wc -l)
- Failed Pods: $(kubectl get pods -n "$NAMESPACE" --field-selector=status.phase=Failed --no-headers | wc -l)
- Pending Pods: $(kubectl get pods -n "$NAMESPACE" --field-selector=status.phase=Pending --no-headers | wc -l)
- Recent Events: $(kubectl get events -n "$NAMESPACE" --no-headers | wc -l)

## Pod Status
\`\`\`
$(kubectl get pods -n "$NAMESPACE" -o wide)
\`\`\`

## Recent Events
\`\`\`
$(kubectl get events -n "$NAMESPACE" --sort-by='.lastTimestamp' | tail -20)
\`\`\`

## Next Steps
1. Review pod logs in logs/ directory
2. Check events/namespace-events.txt for issues
3. Analyze metrics in metrics/ directory
4. Review resource manifests in manifests/ directory

## Files Collected
$(find "$OUTPUT_DIR" -type f | sort)
EOF

    log "Summary created at $OUTPUT_DIR/SUMMARY.md"
}

create_archive() {
    log "Creating archive..."
    
    archive_name="gridos-diagnostics-$(date +%Y%m%d-%H%M%S).tar.gz"
    tar -czf "/tmp/$archive_name" -C "$(dirname "$OUTPUT_DIR")" "$(basename "$OUTPUT_DIR")"
    
    log "✓ Diagnostics archive created: /tmp/$archive_name"
    echo "/tmp/$archive_name"
}

main() {
    log "=== GridOS Diagnostic Collection Started ==="
    
    create_output_dir
    collect_cluster_info
    collect_namespace_resources
    collect_pod_logs
    collect_events
    collect_metrics
    collect_database_info
    collect_network_info
    create_summary
    
    archive_path=$(create_archive)
    
    log "=== Diagnostic Collection Complete ==="
    log "Archive location: $archive_path"
    log "Upload this file when creating a support ticket"
}

main "$@"
