#!/bin/bash

# Install Application Gateway Ingress Controller (AGIC) and Flagger
# for production-grade canary deployments in Azure AKS

set -e

echo "========================================================="
echo "Application Gateway Ingress Controller (AGIC) Setup"
echo "========================================================="

# Variables - UPDATE THESE
SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:-1e371d35-9938-4d5c-94ef-a1b1f9d32e31}"
RESOURCE_GROUP="${RESOURCE_GROUP:-dev-gridos-rg}"
LOCATION="${LOCATION:-eastus}"
AKS_CLUSTER="${AKS_CLUSTER:-dev-gridos-aks}"
APP_GATEWAY_NAME="${APP_GATEWAY_NAME:-gridos-appgw}"
APP_GATEWAY_SUBNET_NAME="${APP_GATEWAY_SUBNET_NAME:-appgw-subnet}"
VNET_NAME="${VNET_NAME:-dev-gridos-vnet}"
APP_NAMESPACE="gridos"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

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

if ! command -v az &> /dev/null; then
    print_error "Azure CLI is not installed. Please install it first."
    exit 1
fi

if ! command -v helm &> /dev/null; then
    print_error "Helm is not installed. Please install Helm first."
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed. Please install kubectl first."
    exit 1
fi

print_step "Prerequisites check passed ✓"

# Login and set subscription
print_step "Setting Azure subscription..."
az account set --subscription "$SUBSCRIPTION_ID"
print_step "Using subscription: $(az account show --query name -o tsv)"

# Get AKS credentials
print_step "Getting AKS credentials..."
az aks get-credentials \
  --resource-group "$RESOURCE_GROUP" \
  --name "$AKS_CLUSTER" \
  --overwrite-existing

# Get VNet and Subnet IDs
print_step "Getting VNet and Subnet information..."
VNET_ID=$(az network vnet show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$VNET_NAME" \
  --query id -o tsv)

print_step "VNet ID: $VNET_ID"

# Check if Application Gateway subnet exists, create if not
print_step "Checking Application Gateway subnet..."
APPGW_SUBNET_ID=$(az network vnet subnet show \
  --resource-group "$RESOURCE_GROUP" \
  --vnet-name "$VNET_NAME" \
  --name "$APP_GATEWAY_SUBNET_NAME" \
  --query id -o tsv 2>/dev/null || echo "")

if [ -z "$APPGW_SUBNET_ID" ]; then
    print_warning "Application Gateway subnet not found. Creating..."
    az network vnet subnet create \
      --resource-group "$RESOURCE_GROUP" \
      --vnet-name "$VNET_NAME" \
      --name "$APP_GATEWAY_SUBNET_NAME" \
      --address-prefixes 10.1.1.0/24
    
    APPGW_SUBNET_ID=$(az network vnet subnet show \
      --resource-group "$RESOURCE_GROUP" \
      --vnet-name "$VNET_NAME" \
      --name "$APP_GATEWAY_SUBNET_NAME" \
      --query id -o tsv)
fi

print_step "Application Gateway Subnet ID: $APPGW_SUBNET_ID"

# Check if Application Gateway exists
print_step "Checking if Application Gateway exists..."
APP_GATEWAY_EXISTS=$(az network application-gateway show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$APP_GATEWAY_NAME" 2>/dev/null || echo "")

if [ -z "$APP_GATEWAY_EXISTS" ]; then
    print_step "Creating Application Gateway (this takes 10-15 minutes)..."
    
    # Create public IP for Application Gateway
    print_step "Creating public IP for Application Gateway..."
    az network public-ip create \
      --resource-group "$RESOURCE_GROUP" \
      --name "${APP_GATEWAY_NAME}-pip" \
      --allocation-method Static \
      --sku Standard \
      --location "$LOCATION"
    
    # Create Application Gateway
    az network application-gateway create \
      --name "$APP_GATEWAY_NAME" \
      --resource-group "$RESOURCE_GROUP" \
      --location "$LOCATION" \
      --sku Standard_v2 \
      --capacity 2 \
      --vnet-name "$VNET_NAME" \
      --subnet "$APP_GATEWAY_SUBNET_NAME" \
      --public-ip-address "${APP_GATEWAY_NAME}-pip" \
      --http-settings-cookie-based-affinity Disabled \
      --frontend-port 80 \
      --http-settings-port 80 \
      --http-settings-protocol Http \
      --priority 100
    
    print_step "Application Gateway created ✓"
else
    print_step "Application Gateway already exists ✓"
fi

# Get Application Gateway ID
APP_GATEWAY_ID=$(az network application-gateway show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$APP_GATEWAY_NAME" \
  --query id -o tsv)

print_step "Application Gateway ID: $APP_GATEWAY_ID"

# Enable AGIC add-on for AKS
print_step "Enabling AGIC add-on for AKS..."
az aks enable-addons \
  --resource-group "$RESOURCE_GROUP" \
  --name "$AKS_CLUSTER" \
  --addons ingress-appgw \
  --appgw-id "$APP_GATEWAY_ID" \
  --yes 2>/dev/null || print_warning "AGIC add-on may already be enabled"

print_step "Waiting for AGIC pods to be ready..."
kubectl wait --namespace kube-system \
  --for=condition=ready pod \
  --selector=app=ingress-appgw \
  --timeout=300s || print_warning "AGIC pods not ready yet, continuing..."

print_step "AGIC installed ✓"

# Install Flagger for canary deployments
print_step "Installing Flagger for Application Gateway..."

helm repo add flagger https://flagger.app 2>/dev/null || true
helm repo update

helm upgrade --install flagger flagger/flagger \
  --namespace flagger-system \
  --create-namespace \
  --set meshProvider=appmesh \
  --set metricsServer=http://prometheus-server.monitoring:80 \
  --set prometheus.install=false \
  --wait \
  --timeout 3m

print_step "Flagger installed ✓"

# Install Flagger Load Tester
print_step "Installing Flagger Load Tester..."

helm upgrade --install flagger-loadtester flagger/loadtester \
  --namespace flagger-system \
  --set cmd.timeout=1h \
  --wait \
  --timeout 3m

print_step "Flagger Load Tester installed ✓"

# Create application namespace
print_step "Creating application namespace..."
kubectl create namespace $APP_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Get Application Gateway public IP
APP_GATEWAY_PIP=$(az network public-ip show \
  --resource-group "$RESOURCE_GROUP" \
  --name "${APP_GATEWAY_NAME}-pip" \
  --query ipAddress -o tsv)

print_step "Application Gateway Public IP: $APP_GATEWAY_PIP"

# Create Prometheus ServiceMonitor for Application Gateway metrics
print_step "Creating Prometheus ServiceMonitor..."

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: appgw-metrics
  namespace: kube-system
  labels:
    app: ingress-appgw
spec:
  type: ClusterIP
  ports:
  - name: metrics
    port: 8080
    targetPort: 8080
    protocol: TCP
  selector:
    app: ingress-appgw
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: appgw-controller
  namespace: monitoring
  labels:
    app: ingress-appgw
spec:
  namespaceSelector:
    matchNames:
    - kube-system
  selector:
    matchLabels:
      app: ingress-appgw
  endpoints:
  - port: metrics
    interval: 30s
EOF

print_step "Prometheus ServiceMonitor created ✓"

# Verify installation
print_step "Verifying installation..."

echo ""
echo "========================================================="
echo "Installation Summary"
echo "========================================================="
echo ""

# Application Gateway
echo "Application Gateway:"
echo "  Name: $APP_GATEWAY_NAME"
echo "  Resource Group: $RESOURCE_GROUP"
echo "  Public IP: $APP_GATEWAY_PIP"
echo ""

# AGIC
echo "AGIC Controller:"
kubectl get pods -n kube-system -l app=ingress-appgw
echo ""

# Flagger
echo "Flagger:"
kubectl get pods -n flagger-system
echo ""

# Installation complete
print_step "Installation complete! ✓"

echo ""
echo "========================================================="
echo "Next Steps"
echo "========================================================="
echo ""
echo "1. Update DNS records:"
echo "   gridos.example.com -> $APP_GATEWAY_PIP"
echo ""
echo "2. Deploy your application with Ingress:"
echo "   helm upgrade --install gridos kubernetes/helm-charts/gridos \\"
echo "     --namespace $APP_NAMESPACE \\"
echo "     --set ingress.enabled=true \\"
echo "     --set ingress.className=azure-application-gateway \\"
echo "     --set ingress.hosts[0].host=gridos.example.com"
echo ""
echo "3. Apply Flagger canary configuration:"
echo "   kubectl apply -f kubernetes/flagger/gridos-canary-appgw.yaml"
echo ""
echo "4. Trigger canary deployment:"
echo "   kubectl set image deployment/gridos gridos=yourregistry/gridos:v2 -n $APP_NAMESPACE"
echo ""
echo "5. Monitor canary progress:"
echo "   kubectl get canaries -n $APP_NAMESPACE --watch"
echo "   kubectl describe canary gridos -n $APP_NAMESPACE"
echo ""
echo "6. View in Azure Portal:"
echo "   https://portal.azure.com/#@/resource$APP_GATEWAY_ID"
echo ""

# Create helpful commands file
cat <<'EOF' > appgw-commands.sh
#!/bin/bash

# Helpful commands for managing Application Gateway

# View Application Gateway configuration
alias appgw-show='az network application-gateway show --resource-group $RESOURCE_GROUP --name $APP_GATEWAY_NAME'

# View backend health
alias appgw-health='az network application-gateway show-backend-health --resource-group $RESOURCE_GROUP --name $APP_GATEWAY_NAME'

# View rules
alias appgw-rules='az network application-gateway rule list --resource-group $RESOURCE_GROUP --gateway-name $APP_GATEWAY_NAME -o table'

# View backend pools
alias appgw-backends='az network application-gateway address-pool list --resource-group $RESOURCE_GROUP --gateway-name $APP_GATEWAY_NAME -o table'

# Watch canary deployments
alias watch-canary='watch -n 2 "kubectl get canaries,deployments,pods -n gridos"'

# View AGIC logs
alias agic-logs='kubectl logs -n kube-system -l app=ingress-appgw -f'

# View Flagger logs
alias flagger-logs='kubectl logs -n flagger-system -l app.kubernetes.io/name=flagger -f'

# Get Application Gateway metrics
alias appgw-metrics='az monitor metrics list --resource $APP_GATEWAY_ID --metric "TotalRequests" "FailedRequests" "HealthyHostCount" --interval PT1M'

echo "Helpful aliases loaded!"
echo "Usage: appgw-show, appgw-health, appgw-rules, watch-canary, etc."
EOF

chmod +x appgw-commands.sh

print_step "Created appgw-commands.sh with helpful aliases"
print_step "Run: source appgw-commands.sh"

echo ""
print_step "All done! 🚀"
echo ""
