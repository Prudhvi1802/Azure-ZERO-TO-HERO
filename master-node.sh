#!/bin/bash
# Production-ready Kubernetes cluster setup for Java Microservices
# This script sets up a complete Kubernetes environment for Java microservices
# with GitHub Container Registry integration and production-ready configurations.

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

function print_success() { echo -e "${GREEN}✓ $1${NC}"; }
function print_info() { echo -e "${CYAN}ℹ $1${NC}"; }
function print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
function print_error() { echo -e "${RED}✗ $1${NC}"; }

# Parse arguments
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
GITHUB_USERNAME="${GITHUB_USERNAME:-}"
CLUSTER_TYPE="${1:-minikube}"

print_info "=========================================="
print_info "Kubernetes Cluster Setup for Java Microservices"
print_info "=========================================="

# Validate prerequisites
print_info "Checking prerequisites..."

check_command() {
    if command -v $1 &> /dev/null; then
        print_success "$1 is installed"
        return 0
    else
        print_error "$1 is not installed. Please install it first."
        return 1
    fi
}

check_command kubectl || exit 1
check_command docker || exit 1

if [ "$CLUSTER_TYPE" == "minikube" ]; then
    check_command minikube || exit 1
elif [ "$CLUSTER_TYPE" == "kind" ]; then
    check_command kind || exit 1
fi

# Setup cluster based on type
if [ "$CLUSTER_TYPE" == "minikube" ]; then
    print_info "Setting up Minikube cluster..."
    
    # Check if minikube is running
    if ! minikube status &> /dev/null; then
        print_info "Starting Minikube cluster..."
        minikube start --cpus=4 --memory=8192 --driver=docker --kubernetes-version=stable
    else
        print_success "Minikube is already running"
    fi
    
    # Enable addons
    print_info "Enabling Minikube addons..."
    minikube addons enable ingress
    minikube addons enable metrics-server
    print_success "Minikube addons enabled"
    
elif [ "$CLUSTER_TYPE" == "kind" ]; then
    print_info "Setting up Kind cluster..."
    
    # Check if cluster exists
    if ! kind get clusters 2>&1 | grep -q "ajwa-services"; then
        print_info "Creating Kind cluster..."
        
        # Create kind config
        cat <<EOF > kind-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
- role: worker
- role: worker
EOF
        
        kind create cluster --name ajwa-services --config kind-config.yaml
        rm kind-config.yaml
        print_success "Kind cluster created"
        
        # Install ingress controller
        print_info "Installing NGINX Ingress Controller..."
        kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
        sleep 10
    else
        print_success "Kind cluster already exists"
        kubectl cluster-info --context kind-ajwa-services
    fi
else
    print_info "Using existing cluster..."
    kubectl cluster-info
fi

# Verify cluster is accessible
print_info "Verifying cluster connectivity..."
if kubectl get nodes &> /dev/null; then
    print_success "Cluster is accessible"
else
    print_error "Cannot access cluster. Please check your kubeconfig."
    exit 1
fi

# Create namespace
print_info "Creating namespace..."
kubectl apply -f k8s/namespace.yaml
print_success "Namespace created"

# Create GitHub Container Registry secret if credentials provided
if [ -n "$GITHUB_TOKEN" ] && [ -n "$GITHUB_USERNAME" ]; then
    print_info "Creating GitHub Container Registry secret..."
    
    kubectl create secret docker-registry ghcr-secret \
        --docker-server=ghcr.io \
        --docker-username=$GITHUB_USERNAME \
        --docker-password=$GITHUB_TOKEN \
        --docker-email=$GITHUB_USERNAME@users.noreply.github.com \
        --namespace=ajwa-services \
        --dry-run=client -o yaml | kubectl apply -f -
    
    print_success "GitHub Container Registry secret created"
else
    print_warning "GitHub credentials not provided. Skipping registry secret creation."
    print_warning "Set GITHUB_TOKEN and GITHUB_USERNAME environment variables."
fi

# Apply RBAC configurations
print_info "Applying RBAC configurations..."
kubectl apply -f k8s/rbac.yaml
print_success "RBAC configurations applied"

# Apply ConfigMaps
print_info "Applying ConfigMaps..."
kubectl apply -f k8s/configmap.yaml
print_success "ConfigMaps applied"

# Deploy microservices
print_info "Deploying microservices..."
kubectl apply -f k8s/deployments/
print_success "Microservices deployed"

# Create services
print_info "Creating services..."
kubectl apply -f k8s/services/
print_success "Services created"

# Apply Ingress
if [ -f "k8s/ingress.yaml" ]; then
    print_info "Applying Ingress configuration..."
    kubectl apply -f k8s/ingress.yaml
    print_success "Ingress configured"
fi

# Apply monitoring
if [ -d "k8s/monitoring/" ]; then
    print_info "Setting up monitoring..."
    kubectl apply -f k8s/monitoring/
    print_success "Monitoring configured"
fi

# Wait for deployments to be ready
print_info "Waiting for deployments to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment --all -n ajwa-services
print_success "All deployments are ready"

# Display cluster information
print_info ""
print_info "=========================================="
print_success "Kubernetes Cluster Setup Complete!"
print_info "=========================================="
print_info ""

print_info "Cluster Information:"
kubectl cluster-info

print_info ""
print_info "Deployed Resources:"
kubectl get all -n ajwa-services

print_info ""
print_info "Ingress Status:"
kubectl get ingress -n ajwa-services

if [ "$CLUSTER_TYPE" == "minikube" ]; then
    print_info ""
    print_info "To access services, run: minikube service -n ajwa-services <service-name>"
    print_info "Or get Minikube IP with: minikube ip"
fi

print_info ""
print_info "Useful Commands:"
print_info "  - View logs: kubectl logs -f <pod-name> -n ajwa-services"
print_info "  - View pods: kubectl get pods -n ajwa-services"
print_info "  - View services: kubectl get svc -n ajwa-services"
print_info "  - Delete deployment: kubectl delete -f k8s/"
print_info ""
print_success "Setup completed successfully!"

