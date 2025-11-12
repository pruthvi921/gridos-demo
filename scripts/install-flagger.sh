#!/bin/bash

# Deploy NGINX Ingress Controller and Flagger for Canary Deployments
# This script sets up progressive delivery infrastructure in AKS

set -e

echo "=================================================="
echo "Installing NGINX Ingress Controller + Flagger"
echo "=================================================="

# Variables
NGINX_NAMESPACE="ingress-nginx"
FLAGGER_NAMESPACE="flagger-system"
APP_NAMESPACE="gridos"
PROMETHEUS_ENDPOINT="http://prometheus-server.monitoring:80"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

print_step() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

print_error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

# Check prerequisites
print_step "Checking prerequisites..."

if ! command -v helm &> /dev/null; then
    print_error "Helm is not installed. Please install Helm first."
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed. Please install kubectl first."
    exit 1
fi

# Check AKS connectivity
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster. Please check your kubeconfig."
    exit 1
fi

print_step "Prerequisites check passed ✓"

# Step 1: Install NGINX Ingress Controller
print_step "Installing NGINX Ingress Controller..."

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx 2>/dev/null || true
helm repo update

helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace $NGINX_NAMESPACE \
  --create-namespace \
  --set controller.replicaCount=2 \
  --set controller.nodeSelector."kubernetes\.io/os"=linux \
  --set controller.admissionWebhooks.patch.nodeSelector."kubernetes\.io/os"=linux \
  --set controller.service.type=LoadBalancer \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"="/healthz" \
  --set controller.metrics.enabled=true \
  --set controller.metrics.serviceMonitor.enabled=true \
  --set controller.metrics.serviceMonitor.namespace=$NGINX_NAMESPACE \
  --set controller.podAnnotations."prometheus\.io/scrape"="true" \
  --set controller.podAnnotations."prometheus\.io/port"="10254" \
  --set controller.resources.requests.cpu="100m" \
  --set controller.resources.requests.memory="256Mi" \
  --set controller.resources.limits.cpu="500m" \
  --set controller.resources.limits.memory="512Mi" \
  --wait \
  --timeout 5m

print_step "Waiting for NGINX Ingress Controller to be ready..."
kubectl wait --namespace $NGINX_NAMESPACE \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=300s

print_step "NGINX Ingress Controller installed ✓"

# Get the external IP
print_step "Getting NGINX Ingress external IP..."
EXTERNAL_IP=""
for i in {1..30}; do
    EXTERNAL_IP=$(kubectl get svc ingress-nginx-controller -n $NGINX_NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    if [ -n "$EXTERNAL_IP" ]; then
        break
    fi
    echo "Waiting for external IP... ($i/30)"
    sleep 10
done

if [ -n "$EXTERNAL_IP" ]; then
    print_step "NGINX Ingress external IP: $EXTERNAL_IP"
    echo "Add this to your DNS: gridos.example.com -> $EXTERNAL_IP"
else
    print_warning "External IP not yet assigned. Check with: kubectl get svc -n $NGINX_NAMESPACE"
fi

# Step 2: Install Flagger
print_step "Installing Flagger..."

helm repo add flagger https://flagger.app 2>/dev/null || true
helm repo update

helm upgrade --install flagger flagger/flagger \
  --namespace $FLAGGER_NAMESPACE \
  --create-namespace \
  --set meshProvider=nginx \
  --set metricsServer=$PROMETHEUS_ENDPOINT \
  --set prometheus.install=false \
  --set slack.url="" \
  --set slack.channel="" \
  --set slack.user="Flagger" \
  --set crd.create=true \
  --wait \
  --timeout 3m

print_step "Flagger installed ✓"

# Step 3: Install Flagger Load Tester (optional but recommended)
print_step "Installing Flagger Load Tester..."

helm upgrade --install flagger-loadtester flagger/loadtester \
  --namespace $FLAGGER_NAMESPACE \
  --set cmd.timeout=1h \
  --wait \
  --timeout 3m

print_step "Flagger Load Tester installed ✓"

# Step 4: Create app namespace if not exists
print_step "Creating application namespace..."
kubectl create namespace $APP_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Step 5: Apply Flagger canary configuration
print_step "Applying Flagger canary configuration..."

if [ -f "kubernetes/flagger/gridos-canary.yaml" ]; then
    kubectl apply -f kubernetes/flagger/gridos-canary.yaml
    print_step "Canary configuration applied ✓"
else
    print_warning "Canary configuration file not found. Skipping..."
fi

# Step 6: Install Prometheus ServiceMonitor for NGINX (if prometheus-operator is installed)
print_step "Creating Prometheus ServiceMonitor for NGINX Ingress..."

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: ingress-nginx-controller-metrics
  namespace: $NGINX_NAMESPACE
  labels:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/component: controller
spec:
  type: ClusterIP
  ports:
  - name: metrics
    port: 10254
    targetPort: 10254
    protocol: TCP
  selector:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/component: controller
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: ingress-nginx-controller
  namespace: monitoring
  labels:
    app.kubernetes.io/name: ingress-nginx
spec:
  namespaceSelector:
    matchNames:
    - $NGINX_NAMESPACE
  selector:
    matchLabels:
      app.kubernetes.io/name: ingress-nginx
      app.kubernetes.io/component: controller
  endpoints:
  - port: metrics
    interval: 30s
EOF

print_step "Prometheus ServiceMonitor created ✓"

# Step 7: Verify installation
print_step "Verifying installation..."

echo ""
echo "=================================================="
echo "Installation Summary"
echo "=================================================="
echo ""

# NGINX Ingress
echo "NGINX Ingress Controller:"
kubectl get pods -n $NGINX_NAMESPACE -l app.kubernetes.io/component=controller
echo ""

# Flagger
echo "Flagger:"
kubectl get pods -n $FLAGGER_NAMESPACE
echo ""

# Canary CRDs
echo "Canary CRDs:"
kubectl get crd canaries.flagger.app 2>/dev/null || echo "Not installed"
echo ""

# External IP
if [ -n "$EXTERNAL_IP" ]; then
    echo "NGINX Ingress External IP: $EXTERNAL_IP"
    echo ""
fi

# Step 8: Provide next steps
print_step "Installation complete! ✓"

echo ""
echo "=================================================="
echo "Next Steps"
echo "=================================================="
echo ""
echo "1. Update DNS records:"
echo "   gridos.example.com -> $EXTERNAL_IP"
echo ""
echo "2. Deploy your application:"
echo "   helm upgrade --install gridos kubernetes/helm-charts/gridos \\"
echo "     --namespace $APP_NAMESPACE \\"
echo "     --set ingress.enabled=true \\"
echo "     --set ingress.hosts[0].host=gridos.example.com"
echo ""
echo "3. Apply Flagger canary:"
echo "   kubectl apply -f kubernetes/flagger/gridos-canary.yaml"
echo ""
echo "4. Trigger canary deployment:"
echo "   # Update image tag in deployment"
echo "   kubectl set image deployment/gridos gridos=yourregistry/gridos:v2 -n $APP_NAMESPACE"
echo ""
echo "5. Watch canary progress:"
echo "   kubectl get canaries -n $APP_NAMESPACE --watch"
echo "   kubectl describe canary gridos -n $APP_NAMESPACE"
echo ""
echo "6. Monitor in Grafana:"
echo "   kubectl port-forward -n monitoring svc/grafana 3000:80"
echo "   Open http://localhost:3000"
echo ""

# Step 9: Create helpful aliases
print_step "Creating helpful bash aliases..."

cat <<'EOF'

# Add these to your ~/.bashrc or ~/.zshrc:

alias k='kubectl'
alias kgc='kubectl get canaries --all-namespaces'
alias kwc='kubectl get canaries --all-namespaces --watch'
alias kdc='kubectl describe canary'
alias flagger-logs='kubectl logs -n flagger-system -l app.kubernetes.io/name=flagger -f'
alias nginx-logs='kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller -f'
alias canary-status='kubectl get canaries -A -o custom-columns=NAME:.metadata.name,NAMESPACE:.metadata.namespace,STATUS:.status.phase,WEIGHT:.status.canaryWeight'

# Function to watch canary deployment
watch-canary() {
    watch -n 2 "kubectl get canaries -A && echo '' && kubectl get pods -n gridos"
}
EOF

echo ""
print_step "All done! 🚀"
echo ""
