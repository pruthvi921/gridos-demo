#!/bin/bash
# Local Development Setup Script
# Sets up the GridOS platform for local development

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    local missing=()
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        missing+=("Docker")
    fi
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        missing+=("kubectl")
    fi
    
    # Check Helm
    if ! command -v helm &> /dev/null; then
        missing+=("Helm")
    fi
    
    # Check .NET SDK
    if ! command -v dotnet &> /dev/null; then
        missing+=(".NET 8 SDK")
    fi
    
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        missing+=("Terraform")
    fi
    
    if [ ${#missing[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing[*]}"
        echo ""
        echo "Please install:"
        echo "  - Docker Desktop: https://www.docker.com/products/docker-desktop"
        echo "  - kubectl: https://kubernetes.io/docs/tasks/tools/"
        echo "  - Helm: https://helm.sh/docs/intro/install/"
        echo "  - .NET 8 SDK: https://dotnet.microsoft.com/download"
        echo "  - Terraform: https://www.terraform.io/downloads"
        exit 1
    fi
    
    log_info "✓ All prerequisites installed"
}

setup_kubernetes() {
    log_info "Setting up Kubernetes..."
    
    # Check if Docker Desktop Kubernetes is enabled
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Kubernetes is not running. Please enable Kubernetes in Docker Desktop settings."
        exit 1
    fi
    
    log_info "✓ Kubernetes is running"
    
    # Create namespaces
    kubectl create namespace gridos --dry-run=client -o yaml | kubectl apply -f -
    kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
    
    log_info "✓ Namespaces created"
}

setup_monitoring() {
    log_info "Setting up monitoring stack..."
    
    # Add Helm repositories
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo add grafana https://grafana.github.io/helm-charts
    helm repo update
    
    # Install Prometheus
    if ! helm status prometheus -n monitoring &> /dev/null; then
        log_info "Installing Prometheus..."
        helm install prometheus prometheus-community/kube-prometheus-stack \
            --namespace monitoring \
            --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
            --wait
    else
        log_info "✓ Prometheus already installed"
    fi
    
    # Install Loki
    if ! helm status loki -n monitoring &> /dev/null; then
        log_info "Installing Loki..."
        helm install loki grafana/loki-stack \
            --namespace monitoring \
            --wait
    else
        log_info "✓ Loki already installed"
    fi
    
    log_info "✓ Monitoring stack ready"
}

setup_database() {
    log_info "Setting up PostgreSQL database..."
    
    # Check if PostgreSQL pod exists
    if ! kubectl get pod postgres-0 -n gridos &> /dev/null; then
        log_info "Creating PostgreSQL StatefulSet..."
        
        cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: postgres-secret
  namespace: gridos
type: Opaque
stringData:
  password: postgres
  connection-string: "Host=postgres;Database=gridos_dev;Username=postgres;Password=postgres;SslMode=Disable"
---
apiVersion: v1
kind: Service
metadata:
  name: postgres
  namespace: gridos
spec:
  ports:
  - port: 5432
    targetPort: 5432
  clusterIP: None
  selector:
    app: postgres
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
  namespace: gridos
spec:
  serviceName: postgres
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:16-alpine
        ports:
        - containerPort: 5432
        env:
        - name: POSTGRES_PASSWORD
          value: postgres
        - name: POSTGRES_DB
          value: gridos_dev
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
  volumeClaimTemplates:
  - metadata:
      name: postgres-storage
    spec:
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 5Gi
EOF
        
        log_info "Waiting for PostgreSQL to be ready..."
        kubectl wait --for=condition=ready pod/postgres-0 -n gridos --timeout=120s
    else
        log_info "✓ PostgreSQL already running"
    fi
}

build_application() {
    log_info "Building GridOS application..."
    
    cd src/GridOS.API
    
    # Restore dependencies
    log_info "Restoring dependencies..."
    dotnet restore
    
    # Build
    log_info "Building application..."
    dotnet build --configuration Release
    
    # Build Docker image
    log_info "Building Docker image..."
    docker build -t gridos-api:dev .
    
    cd ../..
    
    log_info "✓ Application built"
}

deploy_application() {
    log_info "Deploying application to Kubernetes..."
    
    # Install/upgrade Helm chart
    helm upgrade --install gridos ./kubernetes/helm-charts/gridos \
        --namespace gridos \
        --set image.repository=gridos-api \
        --set image.tag=dev \
        --set image.pullPolicy=IfNotPresent \
        --set replicaCount=2 \
        --set database.host=postgres \
        --set database.existingSecret=postgres-secret \
        --wait \
        --timeout 5m
    
    log_info "✓ Application deployed"
}

setup_port_forwards() {
    log_info "Setting up port forwards..."
    
    cat > /tmp/start-port-forwards.sh <<'EOF'
#!/bin/bash
echo "Starting port forwards..."
kubectl port-forward -n gridos svc/gridos 8080:80 &
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090 &
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80 &
echo "Port forwards started!"
echo ""
echo "Access services at:"
echo "  - GridOS API: http://localhost:8080"
echo "  - Swagger UI: http://localhost:8080/swagger"
echo "  - Prometheus: http://localhost:9090"
echo "  - Grafana: http://localhost:3000 (admin/prom-operator)"
echo ""
echo "Press Ctrl+C to stop port forwards"
wait
EOF
    
    chmod +x /tmp/start-port-forwards.sh
    
    log_info "✓ Port forward script created at /tmp/start-port-forwards.sh"
}

print_summary() {
    echo ""
    echo "=========================================="
    echo "   GridOS Platform Setup Complete! 🎉"
    echo "=========================================="
    echo ""
    echo "Next steps:"
    echo ""
    echo "1. Start port forwards:"
    echo "   /tmp/start-port-forwards.sh"
    echo ""
    echo "2. Access services:"
    echo "   - GridOS API: http://localhost:8080"
    echo "   - Swagger UI: http://localhost:8080/swagger"
    echo "   - Prometheus: http://localhost:9090"
    echo "   - Grafana: http://localhost:3000"
    echo "     Username: admin"
    echo "     Password: prom-operator"
    echo ""
    echo "3. Test the API:"
    echo "   curl http://localhost:8080/api/gridnodes"
    echo "   curl http://localhost:8080/health"
    echo ""
    echo "4. View logs:"
    echo "   kubectl logs -n gridos -l app.kubernetes.io/name=gridos --follow"
    echo ""
    echo "5. Import Grafana dashboards:"
    echo "   - Open Grafana at http://localhost:3000"
    echo "   - Go to Dashboards -> Import"
    echo "   - Import from monitoring/grafana/dashboards/"
    echo ""
    echo "=========================================="
}

main() {
    echo "=========================================="
    echo "  GridOS Platform - Local Setup"
    echo "=========================================="
    echo ""
    
    check_prerequisites
    setup_kubernetes
    setup_monitoring
    setup_database
    build_application
    deploy_application
    setup_port_forwards
    print_summary
}

main "$@"
