#!/bin/bash
# Auto-Scale Pods Based on Load
# This script automatically scales pods when resource utilization is high

set -euo pipefail

NAMESPACE="${NAMESPACE:-gridos}"
DEPLOYMENT="${DEPLOYMENT:-gridos-api}"
MAX_REPLICAS="${MAX_REPLICAS:-10}"
MIN_REPLICAS="${MIN_REPLICAS:-2}"
CPU_THRESHOLD="${CPU_THRESHOLD:-80}"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

get_current_replicas() {
    kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" -o jsonpath='{.spec.replicas}'
}

get_cpu_usage() {
    kubectl top pods -n "$NAMESPACE" -l app.kubernetes.io/name=gridos \
        --no-headers | awk '{sum+=$2} END {print sum}'
}

scale_deployment() {
    local target_replicas=$1
    log "Scaling $DEPLOYMENT to $target_replicas replicas..."
    
    kubectl scale deployment "$DEPLOYMENT" -n "$NAMESPACE" --replicas="$target_replicas"
    
    if [ $? -eq 0 ]; then
        log "✓ Successfully scaled to $target_replicas replicas"
        
        # Send notification
        if command -v curl &> /dev/null; then
            curl -X POST "${WEBHOOK_URL}" \
                -H "Content-Type: application/json" \
                -d "{\"text\": \"Auto-scaled $DEPLOYMENT to $target_replicas replicas due to high load\"}" \
                2>/dev/null || true
        fi
    else
        log "✗ Failed to scale deployment"
        exit 1
    fi
}

main() {
    log "Starting auto-scale check for $DEPLOYMENT in namespace $NAMESPACE"
    
    # Check if HPA is enabled
    if kubectl get hpa "$DEPLOYMENT" -n "$NAMESPACE" &>/dev/null; then
        log "HPA is already managing this deployment, exiting"
        exit 0
    fi
    
    current_replicas=$(get_current_replicas)
    log "Current replicas: $current_replicas"
    
    # Get average CPU usage
    avg_cpu=$(kubectl top pods -n "$NAMESPACE" -l app.kubernetes.io/name=gridos \
        --no-headers | awk '{sum+=$2; count++} END {if(count>0) print sum/count; else print 0}' \
        | sed 's/m//')
    
    log "Average CPU usage: ${avg_cpu}m"
    
    # Scale decision
    if [ "${avg_cpu%.*}" -gt "$CPU_THRESHOLD" ] && [ "$current_replicas" -lt "$MAX_REPLICAS" ]; then
        target_replicas=$((current_replicas + 2))
        if [ "$target_replicas" -gt "$MAX_REPLICAS" ]; then
            target_replicas=$MAX_REPLICAS
        fi
        log "CPU usage above threshold ($CPU_THRESHOLD%), scaling up"
        scale_deployment "$target_replicas"
    elif [ "${avg_cpu%.*}" -lt 30 ] && [ "$current_replicas" -gt "$MIN_REPLICAS" ]; then
        target_replicas=$((current_replicas - 1))
        if [ "$target_replicas" -lt "$MIN_REPLICAS" ]; then
            target_replicas=$MIN_REPLICAS
        fi
        log "CPU usage low (<30%), scaling down"
        scale_deployment "$target_replicas"
    else
        log "No scaling action needed"
    fi
}

main "$@"
