#!/bin/bash
#############################################
# Kubernetes Worker Node Initialization Script
# Joins worker node to the Kubernetes cluster
# Ubuntu 24.04/25.04 LTS
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

print_header "Kubernetes Worker Node Initialization"
print_info "Timestamp: $(date)"
echo ""

#############################################
# Check Root Access
#############################################
if [ "$EUID" -ne 0 ]; then 
    print_error "Please run as root (use sudo)"
    exit 1
fi

#############################################
# Pre-flight Checks
#############################################
print_header "Running Pre-flight Checks"

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl not found"
    print_info "Please run prerequisites.sh first"
    exit 1
fi
print_success "kubectl is installed"

# Check if kubeadm is installed
if ! command -v kubeadm &> /dev/null; then
    print_error "kubeadm not found"
    print_info "Please run prerequisites.sh first"
    exit 1
fi
print_success "kubeadm is installed"

# Check if containerd is running
if ! systemctl is-active --quiet containerd; then
    print_error "containerd is not running"
    print_info "Starting containerd..."
    systemctl start containerd
fi
print_success "containerd is running"

# Check if swap is disabled
if [ $(swapon -s | wc -l) -gt 1 ]; then
    print_warning "Swap is enabled, disabling..."
    swapoff -a
    sed -i '/ swap / s/^/#/' /etc/fstab
fi
print_success "Swap is disabled"

# Check if already part of a cluster
if [ -f "/etc/kubernetes/kubelet.conf" ]; then
    print_warning "This node may already be part of a cluster"
    read -p "Reset and rejoin cluster? This will remove this node from any existing cluster! (y/n): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Resetting node..."
        kubeadm reset -f
        rm -rf /etc/kubernetes /var/lib/kubelet ~/.kube
        print_success "Node reset complete"
    else
        print_error "Cannot proceed with existing cluster configuration"
        print_info "Either reset the node or use existing configuration"
        exit 1
    fi
fi

echo ""

#############################################
# Get Worker Node IP
#############################################
print_header "Determining Worker Node IP Address"

# Auto-detect primary IP
print_info "Auto-detecting primary IP address..."

# Try multiple methods to get IP
WORKER_IP=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'src \K[^ ]+' || \
            hostname -I 2>/dev/null | awk '{print $1}' || \
            ip addr show | grep 'inet ' | grep -v '127.0.0.1' | head -1 | awk '{print $2}' | cut -d/ -f1)

if [ -z "$WORKER_IP" ]; then
    print_warning "Could not auto-detect IP address"
    WORKER_IP="unknown"
else
    print_success "Detected Worker IP: $WORKER_IP"
fi

print_info "Worker Hostname: $(hostname)"
echo ""

#############################################
# Get Join Command
#############################################
print_header "Getting Join Command"

# Check if join command provided as arguments
if [ $# -gt 0 ] && [[ "$1" == "kubeadm" ]]; then
    # Join command provided as script arguments
    JOIN_COMMAND="$@"
    print_success "Using join command from arguments"
    
elif [ -n "$1" ]; then
    # First argument might be master IP for SSH fetch
    MASTER_IP="$1"
    
    # Validate IP format
    if [[ $MASTER_IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        print_info "Attempting to fetch join command from master: $MASTER_IP"
        
        # Try to fetch join command via SSH
        if command -v ssh &> /dev/null; then
            print_warning "This requires SSH access to the master node"
            
            # Try to read the join command file
            JOIN_COMMAND=$(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 root@$MASTER_IP "cat /tmp/join-command.sh 2>/dev/null | grep 'kubeadm join'" 2>/dev/null || \
                          ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 azureuser@$MASTER_IP "sudo cat /tmp/join-command.sh 2>/dev/null | grep 'kubeadm join'" 2>/dev/null || \
                          echo "")
            
            if [ -n "$JOIN_COMMAND" ]; then
                print_success "Successfully fetched join command from master"
            else
                print_error "Failed to fetch join command from master via SSH"
                print_info "Join command not found at /tmp/join-command.sh on master"
                JOIN_COMMAND=""
            fi
        else
            print_error "SSH client not available"
            JOIN_COMMAND=""
        fi
    else
        # Not an IP address, treat as join command
        JOIN_COMMAND="$@"
        print_success "Using join command from arguments"
    fi
fi

# If no join command yet, try interactive mode
if [ -z "$JOIN_COMMAND" ]; then
    print_warning "No join command provided"
    echo ""
    print_info "Please provide the join command in one of the following ways:"
    echo ""
    echo "  Method 1: Paste the complete join command"
    echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Example format:"
    echo "  kubeadm join 192.168.1.100:6443 --token abc123.xyz789 \\"
    echo "    --discovery-token-ca-cert-hash sha256:1234567890abcdef..."
    echo ""
    read -p "  Enter join command: " JOIN_COMMAND
    
    if [ -z "$JOIN_COMMAND" ]; then
        print_error "No join command provided"
        echo ""
        print_info "To get the join command:"
        print_info "  1. On master node, run: cat /tmp/join-command.sh"
        print_info "  2. Or generate new: kubeadm token create --print-join-command"
        echo ""
        exit 1
    fi
fi

# Validate join command format
if [[ ! "$JOIN_COMMAND" =~ ^kubeadm[[:space:]]+join ]]; then
    print_error "Invalid join command format"
    print_info "Command must start with 'kubeadm join'"
    print_info "Got: ${JOIN_COMMAND:0:50}..."
    exit 1
fi

# Extract and display master IP from join command
MASTER_ENDPOINT=$(echo "$JOIN_COMMAND" | grep -oP 'join \K[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+' || echo "unknown")
print_success "Join command validated"
print_info "Master endpoint: $MASTER_ENDPOINT"
echo ""

#############################################
# Test Master Connectivity
#############################################
print_header "Testing Master Node Connectivity"

MASTER_IP_ONLY=$(echo "$MASTER_ENDPOINT" | cut -d: -f1)
MASTER_PORT=$(echo "$MASTER_ENDPOINT" | cut -d: -f2)

if [ "$MASTER_IP_ONLY" != "unknown" ]; then
    # Test ping
    print_section "Testing network connectivity to master..."
    if ping -c 2 -W 2 $MASTER_IP_ONLY &> /dev/null; then
        print_success "Can reach master node at $MASTER_IP_ONLY"
    else
        print_warning "Cannot ping master node at $MASTER_IP_ONLY"
        print_info "This is not critical if firewall blocks ICMP"
    fi
    
    # Test API server port
    print_section "Testing API server port..."
    if timeout 5 bash -c "cat < /dev/null > /dev/tcp/$MASTER_IP_ONLY/$MASTER_PORT" 2>/dev/null; then
        print_success "Master API server is reachable at $MASTER_IP_ONLY:$MASTER_PORT"
    else
        print_warning "Cannot connect to master API server at $MASTER_IP_ONLY:$MASTER_PORT"
        print_info "This may cause join to fail. Check firewall rules."
        
        read -p "Continue anyway? (y/n): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
else
    print_warning "Could not extract master IP for connectivity test"
fi

echo ""

#############################################
# Join Cluster
#############################################
print_header "Joining Kubernetes Cluster"
print_info "This may take 2-5 minutes..."
echo ""

print_section "Executing join command..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "$JOIN_COMMAND"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if eval $JOIN_COMMAND; then
    print_success "Successfully joined the cluster"
else
    print_error "Failed to join the cluster"
    echo ""
    print_info "Common issues:"
    print_info "  - Token expired (valid for 24 hours)"
    print_info "  - Firewall blocking port 6443"
    print_info "  - Network connectivity issues"
    print_info "  - Prerequisites not installed"
    echo ""
    print_info "To generate a new token on master:"
    print_info "  kubeadm token create --print-join-command"
    echo ""
    print_info "Check kubelet logs:"
    print_info "  journalctl -u kubelet -f"
    exit 1
fi

echo ""

#############################################
# Verify Node Status
#############################################
print_header "Verifying Node Status"

print_info "Waiting for kubelet to start..."
sleep 5

# Check kubelet status
if systemctl is-active --quiet kubelet; then
    print_success "kubelet is running"
else
    print_warning "kubelet is not running"
    print_info "Starting kubelet..."
    systemctl start kubelet
fi

# Check kubelet logs for errors
print_section "Checking kubelet logs for errors..."
if journalctl -u kubelet --since "2 minutes ago" | grep -i "error" &> /dev/null; then
    print_warning "Some errors found in kubelet logs"
    print_info "Check logs: journalctl -u kubelet -f"
else
    print_success "No critical errors in kubelet logs"
fi

echo ""

#############################################
# Display Node Information
#############################################
print_header "Worker Node Information"

print_section "Node Details"
print_info "Hostname: $(hostname)"
print_info "IP Address: $WORKER_IP"
print_info "Joined to: $MASTER_ENDPOINT"

echo ""
print_section "Kubelet Status"
systemctl status kubelet --no-pager -l | head -10

echo ""

#############################################
# Final Summary
#############################################
print_header "Initialization Complete!"
echo ""

print_success "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
print_success "  Worker Node Successfully Joined Cluster"
print_success "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

print_info "Next Steps:"
echo ""
echo "  1. Verify node status from MASTER node:"
echo "     kubectl get nodes -o wide"
echo ""
echo "  2. Wait for node to become 'Ready' (may take 1-2 minutes):"
echo "     kubectl get nodes -w"
echo ""
echo "  3. Check node details:"
echo "     kubectl describe node $(hostname)"
echo ""
echo "  4. Verify all pods are running:"
echo "     kubectl get pods --all-namespaces -o wide"
echo ""

print_warning "⚠️  IMPORTANT: kubectl Commands NOT Available on Worker Nodes! ⚠️"
echo ""
print_error "❌ DO NOT run 'kubectl' commands on this worker node!"
print_error "❌ Worker nodes do not have cluster configuration (no kubeconfig)"
print_error "❌ Running kubectl here will result in connection errors"
echo ""
print_success "✅ Run ALL kubectl commands on the MASTER node only"
print_success "✅ Connect to master node to verify cluster status"
echo ""
print_warning "Important Notes:"
echo "  - Node may take 1-2 minutes to become 'Ready'"
echo "  - Check node status from MASTER node using kubectl"
echo "  - Calico pods should be running on this node"
echo ""

print_info "Troubleshooting:"
echo "  - Check kubelet: journalctl -u kubelet -f"
echo "  - Check containerd: journalctl -u containerd -f"
echo "  - From master: kubectl describe node $(hostname)"
echo ""

print_info "Initialization completed at $(date)"
echo ""
