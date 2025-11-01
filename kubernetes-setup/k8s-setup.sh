#!/bin/bash

# Kubernetes Setup Script for GitLab CI/CD
# This script sets up the complete Kubernetes configuration for deployments

set -e

echo "================================================"
echo "Kubernetes Setup for GitLab CI/CD"
echo "================================================"
echo ""

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is not installed"
    echo "Please install kubectl first"
    exit 1
fi

# Check cluster connectivity
echo "Checking Kubernetes cluster connectivity..."
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Cannot connect to Kubernetes cluster"
    echo "Please configure kubectl to connect to your cluster"
    exit 1
fi

echo "✅ Connected to Kubernetes cluster"
echo ""

# Step 1: Create namespace
echo "Step 1: Creating namespace..."
kubectl apply -f k8s-namespace.yaml
echo "✅ Namespace created"
echo ""

# Step 2: Create ServiceAccount
echo "Step 2: Creating ServiceAccount..."
kubectl apply -f k8s-serviceaccount.yaml
echo "✅ ServiceAccount created"
echo ""

# Step 3: Create RBAC (Role and RoleBinding)
echo "Step 3: Creating RBAC resources..."
kubectl apply -f k8s-rbac.yaml
echo "✅ RBAC resources created"
echo ""

# Wait for secret to be created
echo "Waiting for ServiceAccount token secret to be created..."
sleep 5

# Verify setup
echo "Verifying setup..."
echo ""

echo "Namespace:"
kubectl get namespace production
echo ""

echo "ServiceAccount:"
kubectl get serviceaccount gitlab-deployer -n production
echo ""

echo "Role:"
kubectl get role gitlab-deployer-role -n production
echo ""

echo "RoleBinding:"
kubectl get rolebinding gitlab-deployer-binding -n production
echo ""

echo "Secret:"
kubectl get secret gitlab-deployer-token -n production
echo ""

echo "================================================"
echo "✅ Kubernetes setup complete!"
echo "================================================"
echo ""
echo "Next steps:"
echo "1. Generate kubeconfig: ./generate-kubeconfig.sh"
echo "2. Add the base64 encoded kubeconfig to GitLab CI/CD variables"
echo "3. Configure your .gitlab-ci.yml pipeline"
echo ""
