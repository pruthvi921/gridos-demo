#!/bin/bash
# Install Prometheus + Grafana Observability Stack
# Run after AKS cluster is provisioned

set -e

NAMESPACE="monitoring"
ENVIRONMENT=${1:-dev}  # dev, test, or prod

echo "=================================================="
echo "Installing Observability Stack for $ENVIRONMENT"
echo "=================================================="

# Add Helm repositories
echo "Adding Helm repositories..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Create monitoring namespace
echo "Creating monitoring namespace..."
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Install kube-prometheus-stack (Prometheus + Grafana + Alertmanager)
echo "Installing kube-prometheus-stack..."
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace $NAMESPACE \
  --values ../monitoring/prometheus/values-${ENVIRONMENT}.yaml \
  --wait \
  --timeout 10m

# Install Loki for log aggregation
echo "Installing Loki for logs..."
helm upgrade --install loki grafana/loki-stack \
  --namespace $NAMESPACE \
  --set grafana.enabled=false \
  --set prometheus.enabled=false \
  --set promtail.enabled=true \
  --wait

echo ""
echo "=================================================="
echo "✅ Observability Stack Installed Successfully!"
echo "=================================================="
echo ""
echo "Access Grafana:"
echo "  kubectl port-forward -n $NAMESPACE svc/kube-prometheus-stack-grafana 3000:80"
echo "  Username: admin"
echo "  Password: $(kubectl get secret -n $NAMESPACE kube-prometheus-stack-grafana -o jsonpath='{.data.admin-password}' | base64 -d)"
echo ""
echo "Access Prometheus:"
echo "  kubectl port-forward -n $NAMESPACE svc/kube-prometheus-stack-prometheus 9090:9090"
echo ""
echo "Access AlertManager:"
echo "  kubectl port-forward -n $NAMESPACE svc/kube-prometheus-stack-alertmanager 9093:9093"
echo ""
