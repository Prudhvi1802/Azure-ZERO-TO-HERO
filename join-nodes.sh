#!/bin/bash
#############################################
# Kubernetes Node Join Automation Script
# Automates joining worker nodes to cluster
# Ubuntu 25.04 LTS
#############################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
NC='\033[0m'

function print_success() { echo -e "${GREEN}✓ $1${NC}"; }
function print_info() { echo -e "${CYAN}ℹ $1${NC}"; }
function print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
function print_error() { echo -e "${RED}✗ $1${NC}"; }
function print_header() { echo -e "${BLUE}━━━ $1 ━━━${NC}"; }

print_header "Kubernetes Worker Node Join Automation"
print_info "Timestamp: $(date)"
echo ""

#############################################
# Pre-flight Checks
#############################################
print_header "Pre-flight Checks"

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    print_error "Please run as root (use sudo)"
    exit 1
fi
print_success "Running as root"

# Check if prerequisites are installed
print_info "Checking prerequisites..."

check_command() {
    if command -v $1 &> /dev/null; then
        print_success "$1 is installed"
        return 0
    else
        print_error "$1 is not installed"
        return 1
    fi
}

PREREQ_OK=true
check_command kubeadm || PREREQ_OK=false
check_command kubelet || PREREQ_OK=false
check_command kubectl || PREREQ_OK=false

if [ "$PREREQ_OK" = false ]; then
    print_error "Prerequisites not installed. Please run prerequisites.sh first"
    exit 1
fi

# Check if node already joined
if [ -f /etc/kubernetes/kubelet.conf ]; then
    print_warning "This node appears to be already part of a cluster"
    read -p "Do you want to reset and rejoin? (yes/no): " RESET_CHOICE
    if [ "$RESET_CHOICE" = "yes" ]; then
        print_info "Resetting node..."
        kubeadm reset -f
        rm -rf /etc/kubernetes /var/lib/kubelet ~/.kube
        print_success "Node reset complete"
    else
        print_info "Exiting without changes"
        exit 0
    fi
fi

#############################################
# Get Master Node Information
#############################################
print_header "Master Node Configuration"

# Check if join command provided as argument
if [ -n "$1" ]; then
    if [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        # First argument is an IP address
        MASTER_IP="$1"
        print_info "Master IP: $MASTER_IP"
        
        # Try to fetch join command from master
        print_info "Attempting to retrieve join command from master node..."
        print_warning "This requires SSH access to the master node"
        
        read -p "Enter SSH username for master node [default: root]: " SSH_USER
        SSH_USER="${SSH_USER:-root}"
        
        print_info "Trying to fetch join command via SSH..."
        if ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no $SSH_USER@$MASTER_IP "test -f /tmp/join-command.sh" 2>/dev/null; then
            JOIN_COMMAND=$(ssh -o StrictHostKeyChecking=no $SSH_USER@$MASTER_IP "cat /tmp/join-command.sh | grep 'kubeadm join'" 2>/dev/null)
            if [ -n "$JOIN_COMMAND" ]; then
                print_success "Join command retrieved from master node"
            else
                print_error "Could not retrieve join command from master"
                print_info "Please ensure master-node.sh was run successfully on master"
                exit 1
            fi
        else
            print_warning "Could not access /tmp/join-command.sh on master"
            print_info "Generating new join token from master..."
            
            JOIN_COMMAND=$(ssh -o StrictHostKeyChecking=no $SSH_USER@$MASTER_IP "kubeadm token create --print-join-command" 2>/dev/null)
            if [ -n "$JOIN_COMMAND" ]; then
                print_success "New join command generated from master"
            else
                print_error "Could not generate join command from master"
                print_info "Please manually paste the join command below"
                read -p "> " JOIN_COMMAND
            fi
        fi
    else
        # First argument is the full join command
        JOIN_COMMAND="$@"
        print_info "Using join command from arguments"
    fi
else
    # No arguments provided, ask for join command
    print_info "Please provide either:"
    print_info "  1. Master node IP address (will attempt to fetch join command)"
    print_info "  2. Complete join command from master node"
    echo ""
    read -p "Enter master IP or paste join command: " USER_INPUT
    
    if [[ "$USER_INPUT" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        # User provided IP, try to fetch join command
        MASTER_IP="$USER_INPUT"
        print_info "Testing connectivity to master: $MASTER_IP"
        
        if ping -c 2 -W 5 $MASTER_IP &> /dev/null; then
            print_success "Master node is reachable"
        else
            print_error "Cannot reach master node at $MASTER_IP"
            exit 1
        fi
        
        print_warning "Please paste the join command manually:"
        read -p "> " JOIN_COMMAND
    else
        # User provided full join command
        JOIN_COMMAND="$USER_INPUT"
    fi
fi

#############################################
# Validate Join Command
#############################################
print_header "Validating Join Command"

if [ -z "$JOIN_COMMAND" ]; then
    print_error "No join command provided"
    exit 1
fi

# Validate join command format
if [[ ! "$JOIN_COMMAND" =~ ^kubeadm\ join ]]; then
    print_error "Invalid join command format"
    print_error "Expected format: kubeadm join <master-ip>:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>"
    exit 1
fi

# Extract master IP from join command
MASTER_IP_FROM_CMD=$(echo "$JOIN_COMMAND" | grep -oP '\d+\.\d+\.\d+\.\d+' | head -1)
print_info "Master IP from command: $MASTER_IP_FROM_CMD"

# Test connectivity to master
print_info "Testing connectivity to master node..."
if ping -c 2 -W 5 $MASTER_IP_FROM_CMD &> /dev/null; then
    print_success "Master node is reachable"
else
    print_warning "Cannot ping master node, but will try to join anyway"
fi

# Test API server port
print_info "Testing API server port (6443)..."
if timeout 5 bash -c "cat < /dev/null > /dev/tcp/$MASTER_IP_FROM_CMD/6443" 2>/dev/null; then
    print_success "API server port is accessible"
else
    print_warning "API server port may not be accessible"
    print_warning "Check firewall rules if join fails"
fi

print_success "Join command validated"

#############################################
# Display Node Information
#############################################
print_header "Worker Node Information"

NODE_IP=$(hostname -I | awk '{print $1}')
NODE_HOSTNAME=$(hostname)

print_info "Hostname: $NODE_HOSTNAME"
print_info "IP Address: $NODE_IP"
print_info "OS: $(lsb_release -d | cut -f2)"
print_info "Kernel: $(uname -r)"
print_info "CPU Cores: $(nproc)"
print_info "Memory: $(free -h | awk '/^Mem:/{print $2}')"

#############################################
# Join the Cluster
#############################################
print_header "Joining Kubernetes Cluster"

print_warning "Executing join command..."
print_info "This may take 2-3 minutes..."
echo ""

# Execute join command with retry logic
MAX_RETRIES=3
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if eval $JOIN_COMMAND; then
        print_success "Successfully joined the cluster!"
        break
    else
        RETRY_COUNT=$((RETRY_COUNT + 1))
        if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
            print_warning "Join attempt $RETRY_COUNT failed, retrying in 10 seconds..."
            sleep 10
        else
            print_error "Failed to join cluster after $MAX_RETRIES attempts"
            print_info "Common issues:"
            print_info "  1. Network connectivity to master node"
            print_info "  2. Firewall blocking required ports"
            print_info "  3. Token expired (valid for 24 hours)"
            print_info "  4. Prerequisites not properly installed"
            exit 1
        fi
    fi
done

#############################################
# Post-Join Verification
#############################################
print_header "Post-Join Verification"

# Wait for kubelet to start
print_info "Waiting for kubelet to start..."
sleep 10

if systemctl is-active --quiet kubelet; then
    print_success "kubelet is running"
else
    print_warning "kubelet may not be running properly"
    print_info "Check status with: systemctl status kubelet"
fi

# Check if config file exists
if [ -f /etc/kubernetes/kubelet.conf ]; then
    print_success "Node configuration file created"
else
    print_warning "Node configuration file not found"
fi

#############################################
# Summary
#############################################
print_header "Join Complete!"
echo ""

print_success "Worker node joined the cluster successfully!"
print_info "Node: $NODE_HOSTNAME ($NODE_IP)"
print_info "Master: $MASTER_IP_FROM_CMD"
echo ""

print_header "Verification Steps (Run on Master Node)"
echo ""
echo "  # View all nodes"
echo "  kubectl get nodes -o wide"
echo ""
echo "  # Wait for node to be Ready (may take 1-2 minutes)"
echo "  kubectl get nodes -w"
echo ""
echo "  # View node details"
echo "  kubectl describe node $NODE_HOSTNAME"
echo ""
echo "  # View all pods"
echo "  kubectl get pods --all-namespaces"
echo ""

print_header "Troubleshooting (if node not Ready)"
echo ""
echo "  # On worker node, check kubelet logs"
echo "  journalctl -u kubelet -f"
echo ""
echo "  # Check kubelet status"
echo "  systemctl status kubelet"
echo ""
echo "  # On master, check node events"
echo "  kubectl describe node $NODE_HOSTNAME"
echo ""

print_success "Worker node setup completed successfully!"
echo ""
