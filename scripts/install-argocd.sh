#!/bin/bash
# Argo CD Bootstrap Script
# This is the ONE exception to "everything in Git" - the initial Argo CD installation
# After this runs, Argo CD will manage everything else via GitOps

set -e  # Exit on any error

echo "=================================="
echo "Argo CD Bootstrap Installation"
echo "=================================="
echo ""

# Check prerequisites
echo "Checking prerequisites..."
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found. Please install kubectl first."
    exit 1
fi

if ! command -v helm &> /dev/null; then
    echo "❌ helm not found. Please install helm first."
    exit 1
fi

# Check cluster connectivity
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Cannot connect to Kubernetes cluster. Please check your kubeconfig."
    exit 1
fi

echo "✅ Prerequisites check passed"
echo ""

# Add Argo Helm repository
echo "Adding Argo Helm repository..."
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

echo "✅ Helm repository added"
echo ""

# Install Argo CD
echo "Installing Argo CD..."
helm install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  --values argocd/helm-values/argocd-values.yaml \
  --wait \
  --timeout 10m

echo "✅ Argo CD installed"
echo ""

# Install Argo Rollouts
echo "Installing Argo Rollouts..."
helm install argo-rollouts argo/argo-rollouts \
  --namespace argo-rollouts \
  --create-namespace \
  --wait \
  --timeout 5m

echo "✅ Argo Rollouts installed"
echo ""

# Wait for Argo CD server to be ready
echo "Waiting for Argo CD server to be ready..."
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=argocd-server \
  -n argocd \
  --timeout=5m

echo "✅ Argo CD server ready"
echo ""

# Create Argo CD Applications
echo "Creating Argo CD Applications..."
kubectl apply -f argocd/applications/

echo "✅ Applications created"
echo ""

# Get initial admin password
echo "=================================="
echo "Bootstrap Complete!"
echo "=================================="
echo ""
echo "Argo CD is now installed and managing your applications via GitOps."
echo ""
echo "📝 Initial Admin Credentials:"
echo "   Username: admin"
echo -n "   Password: "
kubectl get secret argocd-initial-admin-secret \
  -n argocd \
  -o jsonpath="{.data.password}" | base64 --decode
echo ""
echo ""
echo "🌐 Access Argo CD:"
echo "   Port-forward: kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "   Then open: https://localhost:8080"
echo ""
echo "   Or configure ingress with your domain from argocd-values.yaml"
echo ""
echo "📋 Next Steps:"
echo "   1. Login to Argo CD UI"
echo "   2. Change admin password: argocd account update-password"
echo "   3. View applications: kubectl get applications -n argocd"
echo "   4. From now on, all changes via Git commits!"
echo ""
echo "✨ GitOps is now active - push to Git and Argo CD will sync automatically"
echo ""
