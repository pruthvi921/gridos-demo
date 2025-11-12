#!/bin/bash
# Restart Unhealthy Pods
# This script identifies and restarts pods that are failing health checks

set -euo pipefail

NAMESPACE="${NAMESPACE:-gridos}"
RESTART_THRESHOLD="${RESTART_THRESHOLD:-5}"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

get_unhealthy_pods() {
    kubectl get pods -n "$NAMESPACE" \
        -o json | jq -r '.items[] | 
        select(.status.containerStatuses[]? | 
        (.restartCount > '"$RESTART_THRESHOLD"' or .ready == false)) | 
        .metadata.name'
}

restart_pod() {
    local pod=$1
    log "Restarting unhealthy pod: $pod"
    
    # Get pod details for logging
    kubectl get pod "$pod" -n "$NAMESPACE" -o yaml > "/tmp/${pod}-pre-restart.yaml"
    
    # Delete the pod (will be recreated by deployment)
    if kubectl delete pod "$pod" -n "$NAMESPACE" --wait=false; then
        log "✓ Successfully triggered restart for $pod"
        return 0
    else
        log "✗ Failed to restart $pod"
        return 1
    fi
}

check_pod_health() {
    local pod=$1
    local max_wait=60
    local count=0
    
    log "Waiting for $pod to become healthy..."
    
    while [ $count -lt $max_wait ]; do
        if kubectl get pod "$pod" -n "$NAMESPACE" &>/dev/null; then
            local ready=$(kubectl get pod "$pod" -n "$NAMESPACE" \
                -o jsonpath='{.status.containerStatuses[0].ready}')
            
            if [ "$ready" == "true" ]; then
                log "✓ Pod $pod is now healthy"
                return 0
            fi
        fi
        
        sleep 2
        count=$((count + 1))
    done
    
    log "⚠ Pod $pod did not become healthy within ${max_wait}s"
    return 1
}

main() {
    log "Checking for unhealthy pods in namespace: $NAMESPACE"
    
    unhealthy_pods=$(get_unhealthy_pods)
    
    if [ -z "$unhealthy_pods" ]; then
        log "No unhealthy pods found"
        exit 0
    fi
    
    log "Found unhealthy pods:"
    echo "$unhealthy_pods"
    
    for pod in $unhealthy_pods; do
        log "Processing pod: $pod"
        
        # Get restart count
        restart_count=$(kubectl get pod "$pod" -n "$NAMESPACE" \
            -o jsonpath='{.status.containerStatuses[0].restartCount}')
        
        log "Pod $pod has $restart_count restarts"
        
        if [ "$restart_count" -gt "$RESTART_THRESHOLD" ]; then
            log "⚠ Pod $pod exceeds restart threshold, manual investigation needed"
            
            # Collect diagnostic information
            kubectl describe pod "$pod" -n "$NAMESPACE" > "/tmp/${pod}-describe.txt"
            kubectl logs "$pod" -n "$NAMESPACE" --tail=100 > "/tmp/${pod}-logs.txt" 2>/dev/null || true
            
            log "Diagnostic files saved to /tmp/${pod}-*"
        else
            restart_pod "$pod"
        fi
    done
    
    log "Health check remediation complete"
}

main "$@"
