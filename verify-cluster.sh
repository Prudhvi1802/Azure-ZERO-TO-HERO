#!/bin/bash
#############################################
# Kubernetes Cluster Verification Script
# Run this on the master node to verify cluster health
# Ubuntu 25.04 LTS
#############################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

function print_success() { echo -e "${GREEN}✓ $1${NC}"; }
function print_info() { echo -e "${CYAN}ℹ $1${NC}"; }
function print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
function print_error() { echo -e "${RED}✗ $1${NC}"; }
function print_header() { echo -e "${BLUE}━━━ $1 ━━━${NC}"; }
function print_section() { echo -e "${MAGENTA}▸ $1${NC}"; }

print_header "Kubernetes Cluster Verification"
print_info "Timestamp: $(date)"
echo ""

#############################################
# Check kubectl Access
#############################################
print_header "Checking kubectl Access"

if ! command -v kubectl &> /dev/null; then
    print_error "kubectl not found"
    exit 1
fi
print_success "kubectl is installed"

if kubectl cluster-info &> /dev/null; then
    print_success "kubectl has cluster access"
else
    print_error "kubectl cannot access cluster"
    print_info "Please ensure kubeconfig is properly configured"
    exit 1
fi

#############################################
# Cluster Information
#############################################
print_header "Cluster Information"

print_section "Cluster Details"
kubectl cluster-info

echo ""
print_section "Kubernetes Version"
SERVER_VERSION=$(kubectl version --short 2>/dev/null | grep "Server Version" || kubectl version -o json | grep -A1 "serverVersion" | grep "gitVersion" | awk '{print $2}' | tr -d '",')
print_info "Server Version: $SERVER_VERSION"

#############################################
# Node Status
#############################################
print_header "Node Status"

echo ""
print_section "All Nodes"
kubectl get nodes -o wide

echo ""
print_section "Node Details"
TOTAL_NODES=$(kubectl get nodes --no-headers | wc -l)
READY_NODES=$(kubectl get nodes --no-headers | grep -w "Ready" | wc -l)
NOT_READY_NODES=$(kubectl get nodes --no-headers | grep -v "Ready" | wc -l || echo "0")

print_info "Total Nodes: $TOTAL_NODES"
print_info "Ready Nodes: $READY_NODES"
if [ "$NOT_READY_NODES" -gt 0 ]; then
    print_warning "Not Ready Nodes: $NOT_READY_NODES"
else
    print_success "All nodes are Ready"
fi

# Check for master/control-plane nodes
MASTER_NODES=$(kubectl get nodes --selector=node-role.kubernetes.io/control-plane --no-headers | wc -l)
WORKER_NODES=$(kubectl get nodes --selector='!node-role.kubernetes.io/control-plane' --no-headers | wc -l)

print_info "Control Plane Nodes: $MASTER_NODES"
print_info "Worker Nodes: $WORKER_NODES"

#############################################
# Component Status
#############################################
print_header "Control Plane Components"

echo ""
print_section "Core Components"
kubectl get pods -n kube-system -o wide | grep -E "kube-apiserver|kube-controller-manager|kube-scheduler|etcd"

#############################################
# CNI Status (Calico)
#############################################
print_header "Network Plugin Status (Calico)"

echo ""
if kubectl get namespace calico-system &> /dev/null; then
    print_success "Calico namespace exists"
    
    print_section "Calico Pods"
    kubectl get pods -n calico-system -o wide
    
    echo ""
    print_section "Calico Operator"
    kubectl get pods -n tigera-operator -o wide
    
    # Check if all Calico pods are running
    CALICO_TOTAL=$(kubectl get pods -n calico-system --no-headers | wc -l)
    CALICO_RUNNING=$(kubectl get pods -n calico-system --no-headers | grep -w "Running" | wc -l)
    
    if [ "$CALICO_TOTAL" -eq "$CALICO_RUNNING" ]; then
        print_success "All Calico pods are running ($CALICO_RUNNING/$CALICO_TOTAL)"
    else
        print_warning "Some Calico pods are not running ($CALICO_RUNNING/$CALICO_TOTAL)"
    fi
else
    print_warning "Calico namespace not found"
    print_info "CNI may not be installed or using different plugin"
fi

#############################################
# System Pods
#############################################
print_header "System Pods Status"

echo ""
print_section "kube-system Namespace"
kubectl get pods -n kube-system -o wide

echo ""
SYSTEM_TOTAL=$(kubectl get pods -n kube-system --no-headers | wc -l)
SYSTEM_RUNNING=$(kubectl get pods -n kube-system --no-headers | grep -w "Running" | wc -l)

if [ "$SYSTEM_TOTAL" -eq "$SYSTEM_RUNNING" ]; then
    print_success "All system pods are running ($SYSTEM_RUNNING/$SYSTEM_TOTAL)"
else
    print_warning "Some system pods are not running ($SYSTEM_RUNNING/$SYSTEM_TOTAL)"
fi

#############################################
# DNS Status
#############################################
print_header "DNS Service (CoreDNS)"

echo ""
print_section "CoreDNS Pods"
kubectl get pods -n kube-system -l k8s-app=kube-dns -o wide

COREDNS_TOTAL=$(kubectl get pods -n kube-system -l k8s-app=kube-dns --no-headers | wc -l)
COREDNS_RUNNING=$(kubectl get pods -n kube-system -l k8s-app=kube-dns --no-headers | grep -w "Running" | wc -l)

if [ "$COREDNS_TOTAL" -eq "$COREDNS_RUNNING" ] && [ "$COREDNS_RUNNING" -gt 0 ]; then
    print_success "CoreDNS is running ($COREDNS_RUNNING pods)"
else
    print_warning "CoreDNS may have issues"
fi

#############################################
# Resource Usage
#############################################
print_header "Resource Usage"

echo ""
print_section "Node Resource Utilization"
kubectl top nodes 2>/dev/null || print_warning "Metrics server not available (kubectl top nodes)"

echo ""
print_section "Pod Resource Usage (Top 10)"
kubectl top pods --all-namespaces 2>/dev/null | head -11 || print_warning "Metrics server not available (kubectl top pods)"

#############################################
# Storage Classes
#############################################
print_header "Storage Configuration"

echo ""
print_section "Storage Classes"
if kubectl get storageclass &> /dev/null; then
    kubectl get storageclass
    
    SC_COUNT=$(kubectl get storageclass --no-headers | wc -l)
    if [ "$SC_COUNT" -gt 0 ]; then
        print_success "Storage classes configured: $SC_COUNT"
    else
        print_warning "No storage classes configured"
    fi
else
    print_warning "No storage classes found"
fi

#############################################
# Persistent Volumes
#############################################
echo ""
print_section "Persistent Volumes"
PV_COUNT=$(kubectl get pv --no-headers 2>/dev/null | wc -l)
if [ "$PV_COUNT" -gt 0 ]; then
    kubectl get pv
    print_info "Persistent Volumes: $PV_COUNT"
else
    print_info "No persistent volumes found"
fi

PVC_COUNT=$(kubectl get pvc --all-namespaces --no-headers 2>/dev/null | wc -l)
if [ "$PVC_COUNT" -gt 0 ]; then
    echo ""
    print_section "Persistent Volume Claims"
    kubectl get pvc --all-namespaces
    print_info "Persistent Volume Claims: $PVC_COUNT"
else
    print_info "No persistent volume claims found"
fi

#############################################
# Services
#############################################
print_header "Services"

echo ""
print_section "All Services"
kubectl get svc --all-namespaces -o wide

#############################################
# Deployments
#############################################
print_header "Deployments"

echo ""
DEPLOY_COUNT=$(kubectl get deployments --all-namespaces --no-headers 2>/dev/null | wc -l)
if [ "$DEPLOY_COUNT" -gt 0 ]; then
    print_section "All Deployments"
    kubectl get deployments --all-namespaces -o wide
    print_info "Total Deployments: $DEPLOY_COUNT"
else
    print_info "No user deployments found (system deployments only)"
fi

#############################################
# Cluster Health Summary
#############################################
print_header "Cluster Health Summary"
echo ""

# Overall health check
ISSUES=0

# Check nodes
if [ "$NOT_READY_NODES" -gt 0 ]; then
    print_error "Issue: $NOT_READY_NODES node(s) not ready"
    ISSUES=$((ISSUES + 1))
fi

# Check system pods
SYSTEM_NOT_RUNNING=$((SYSTEM_TOTAL - SYSTEM_RUNNING))
if [ "$SYSTEM_NOT_RUNNING" -gt 0 ]; then
    print_error "Issue: $SYSTEM_NOT_RUNNING system pod(s) not running"
    ISSUES=$((ISSUES + 1))
fi

# Check Calico
if kubectl get namespace calico-system &> /dev/null; then
    CALICO_NOT_RUNNING=$((CALICO_TOTAL - CALICO_RUNNING))
    if [ "$CALICO_NOT_RUNNING" -gt 0 ]; then
        print_error "Issue: $CALICO_NOT_RUNNING Calico pod(s) not running"
        ISSUES=$((ISSUES + 1))
    fi
fi

# Check CoreDNS
if [ "$COREDNS_RUNNING" -eq 0 ]; then
    print_error "Issue: CoreDNS not running"
    ISSUES=$((ISSUES + 1))
fi

# Final summary
echo ""
if [ "$ISSUES" -eq 0 ]; then
    print_success "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_success "  CLUSTER IS HEALTHY - NO ISSUES FOUND  "
    print_success "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
else
    print_warning "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_warning "  CLUSTER HAS $ISSUES ISSUE(S) - REVIEW ABOVE  "
    print_warning "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
fi

echo ""
print_info "Cluster verification completed at $(date)"
echo ""

#############################################
# Additional Commands
#############################################
print_header "Useful Troubleshooting Commands"
echo ""
echo "  # Check node details"
echo "  kubectl describe node <node-name>"
echo ""
echo "  # Check pod logs"
echo "  kubectl logs -n <namespace> <pod-name>"
echo ""
echo "  # Check events"
echo "  kubectl get events --all-namespaces --sort-by='.lastTimestamp'"
echo ""
echo "  # Check component logs"
echo "  journalctl -u kubelet -f"
echo ""
echo "  # Check Calico status"
echo "  kubectl get pods -n calico-system"
echo "  kubectl logs -n calico-system <calico-pod-name>"
echo ""
