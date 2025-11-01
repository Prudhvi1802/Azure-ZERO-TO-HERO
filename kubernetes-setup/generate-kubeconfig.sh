#!/bin/bash

# Script to generate kubeconfig for GitLab CI/CD
# This creates a kubeconfig file using the ServiceAccount token

set -e

echo "================================================"
echo "Generate Kubeconfig for GitLab CI/CD"
echo "================================================"
echo ""

# Variables
NAMESPACE="production"
SERVICE_ACCOUNT="gitlab-deployer"
SECRET_NAME="gitlab-deployer-token"
KUBECONFIG_OUTPUT="gitlab-ci-kubeconfig.yaml"

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is not installed"
    exit 1
fi

# Check if the namespace exists
if ! kubectl get namespace $NAMESPACE &> /dev/null; then
    echo "❌ Namespace '$NAMESPACE' does not exist"
    echo "Run: kubectl apply -f k8s-namespace.yaml"
    exit 1
fi

# Check if the service account exists
if ! kubectl get serviceaccount $SERVICE_ACCOUNT -n $NAMESPACE &> /dev/null; then
    echo "❌ ServiceAccount '$SERVICE_ACCOUNT' does not exist in namespace '$NAMESPACE'"
    echo "Run: kubectl apply -f k8s-serviceaccount.yaml"
    exit 1
fi

# Check if the secret exists
if ! kubectl get secret $SECRET_NAME -n $NAMESPACE &> /dev/null; then
    echo "❌ Secret '$SECRET_NAME' does not exist in namespace '$NAMESPACE'"
    echo "The secret should be auto-created with the ServiceAccount"
    exit 1
fi

echo "Extracting cluster information..."

# Get cluster information
CLUSTER_NAME=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}')
CLUSTER_SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
CLUSTER_CA=$(kubectl config view --minify --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')

# If CA is not in config, get it from the current cluster
if [ -z "$CLUSTER_CA" ]; then
    echo "Extracting CA from cluster..."
    CLUSTER_CA=$(kubectl config view --minify --raw -o jsonpath='{.clusters[0].cluster.certificate-authority}' | base64 -w 0)
fi

echo "Extracting ServiceAccount token..."

# Get the token from the secret
TOKEN=$(kubectl get secret $SECRET_NAME -n $NAMESPACE -o jsonpath='{.data.token}' | base64 -d)

if [ -z "$TOKEN" ]; then
    echo "❌ Failed to extract token from secret"
    exit 1
fi

echo "Generating kubeconfig file..."

# Create the kubeconfig file
cat > $KUBECONFIG_OUTPUT << EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority-data: ${CLUSTER_CA}
    server: ${CLUSTER_SERVER}
  name: ${CLUSTER_NAME}
contexts:
- context:
    cluster: ${CLUSTER_NAME}
    namespace: ${NAMESPACE}
    user: ${SERVICE_ACCOUNT}
  name: gitlab-ci-context
current-context: gitlab-ci-context
users:
- name: ${SERVICE_ACCOUNT}
  user:
    token: ${TOKEN}
EOF

echo ""
echo "================================================"
echo "✅ Kubeconfig generated successfully!"
echo "================================================"
echo ""
echo "File: $KUBECONFIG_OUTPUT"
echo ""
echo "To use this kubeconfig locally for testing:"
echo "  export KUBECONFIG=$PWD/$KUBECONFIG_OUTPUT"
echo "  kubectl get pods -n $NAMESPACE"
echo ""
echo "For GitLab CI/CD:"
echo "1. Encode the file to base64:"
echo "   cat $KUBECONFIG_OUTPUT | base64 -w 0"
echo ""
echo "2. Copy the base64 output"
echo ""
echo "3. In GitLab, go to: Settings → CI/CD → Variables"
echo ""
echo "4. Add a new variable:"
echo "   Key: KUBE_CONFIG"
echo "   Value: <paste base64 output>"
echo "   Type: Variable"
echo "   Protected: Yes (recommended)"
echo "   Masked: Yes (recommended)"
echo ""
echo "⚠️  IMPORTANT SECURITY NOTES:"
echo "  - Keep this file secure and private"
echo "  - Do not commit this file to version control"
echo "  - Rotate tokens periodically"
echo "  - Use GitLab's protected variables feature"
echo ""

# Show base64 encoded version
echo "Base64 encoded kubeconfig (for GitLab CI/CD variable):"
echo "================================================================"
cat $KUBECONFIG_OUTPUT | base64 -w 0
echo ""
echo "================================================================"
echo ""
