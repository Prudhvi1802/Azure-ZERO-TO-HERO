#!/bin/bash
#############################################
# Kubernetes Worker Node Setup Script
# Run this ONLY on worker nodes
# Ubuntu 24.04 LTS (also works on 20.04/22.04)
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

# Configuration (can be overridden with env vars)
SKIP_VERSION_CHECK=${SKIP_VERSION_CHECK:-false}

print_info "=========================================="
print_info "Kubernetes Worker Node Setup"
print_info "=========================================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    print_error "Please run as root (use sudo)"
    exit 1
fi

# Check Ubuntu version (non-interactive)
print_info "Checking Ubuntu version..."
if [ -f /etc/os-release ]; then
    . /etc/os-release
    print_info "OS: $NAME $VERSION"
    if [[ "$VERSION_ID" != "24.04" ]] && [[ "$VERSION_ID" != "22.04" ]] && [[ "$VERSION_ID" != "20.04" ]]; then
        if [[ "$SKIP_VERSION_CHECK" == "true" ]]; then
            print_warning "Ubuntu $VERSION_ID detected. Continuing anyway (SKIP_VERSION_CHECK=true)"
        else
            print_warning "Ubuntu $VERSION_ID detected. Recommended: 24.04, 22.04, or 20.04 LTS"
            print_info "Continuing with current version..."
        fi
    else
        print_success "Ubuntu $VERSION_ID is supported"
    fi
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

# Get join command (non-interactive - must be provided as argument or env var)
if [ -n "$1" ]; then
    # Join command provided as script arguments
    JOIN_COMMAND="$@"
    print_info "Using join command from arguments"
elif [ -n "$JOIN_COMMAND" ]; then
    # Join command provided via environment variable
    print_info "Using join command from JOIN_COMMAND environment variable"
else
    # No join command provided
    print_error "No join command provided"
    print_info ""
    print_info "Usage:"
    print_info "  $0 <join-command>"
    print_info "  OR"
    print_info "  JOIN_COMMAND='kubeadm join ...' $0"
    print_info ""
    print_info "Example:"
    print_info "  $0 kubeadm join 192.168.1.100:6443 --token abc123.xyz789 --discovery-token-ca-cert-hash sha256:abcd..."
    print_info ""
    print_info "Get join command from master node:"
    print_info "  cat /tmp/join-command.sh"
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
