#!/bin/bash
#############################################
# Kubernetes Worker Node Setup Script
# Run this ONLY on worker nodes
# Ubuntu 20.04/22.04 LTS
#############################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

function print_success() { echo -e "${GREEN}✓ $1${NC}"; }
function print_info() { echo -e "${CYAN}ℹ $1${NC}"; }
function print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
function print_error() { echo -e "${RED}✗ $1${NC}"; }

print_info "=========================================="
print_info "Kubernetes Worker Node Setup"
print_info "=========================================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    print_error "Please run as root (use sudo)"
    exit 1
fi

# Check if prerequisites are installed
if ! command -v kubeadm &> /dev/null; then
    print_error "kubeadm not found. Please run setup-prerequisites.sh first"
    exit 1
fi

# Get the node IP address
NODE_IP=$(hostname -I | awk '{print $1}')
print_info "Worker Node IP: $NODE_IP"
print_info "Worker Node Hostname: $(hostname)"

print_info ""
print_warning "You need the join command from the master node"
print_info "The join command looks like:"
print_info "  kubeadm join <master-ip>:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>"
print_info ""

# Check if join command provided as argument
if [ -n "$1" ]; then
    print_info "Using join command from arguments"
    JOIN_COMMAND="$@"
else
    # Ask for join command
    print_warning "Please paste the join command from the master node:"
    read -p "> " JOIN_COMMAND
fi

if [ -z "$JOIN_COMMAND" ]; then
    print_error "No join command provided"
    exit 1
fi

# Validate join command
if [[ ! "$JOIN_COMMAND" =~ ^kubeadm\ join ]]; then
    print_error "Invalid join command. Must start with 'kubeadm join'"
    exit 1
fi

print_info ""
print_info "Joining cluster..."
print_warning "This may take a few minutes..."

# Execute join command
eval $JOIN_COMMAND

print_success "Worker node joined the cluster successfully!"

print_info ""
print_info "=========================================="
print_success "Worker Node Setup Complete!"
print_info "=========================================="
print_info ""

print_info "Next steps:"
print_info "  1. On MASTER node, verify: kubectl get nodes"
print_info "  2. Wait for this node to be 'Ready' status"
print_info "  3. Deploy applications from master node"
print_info ""

print_info "To verify from master node:"
print_info "  kubectl get nodes -o wide"
print_info "  kubectl get pods --all-namespaces"
print_info ""

print_success "Worker node setup completed successfully!"

