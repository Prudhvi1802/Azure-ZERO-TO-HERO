#!/bin/bash
#############################################
# Kubernetes Master Node Setup Script
# Run this ONLY on the master/control plane node
# Ubuntu 25.04 LTS
# Uses kubeadm for multi-VM cluster setup
# CNI: Calico (192.168.0.0/16)
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

# Logging
LOG_FILE="/var/log/k8s-master-setup.log"
exec 1> >(tee -a "$LOG_FILE")
exec 2>&1

print_header "Kubernetes Master Node Setup"
print_info "Timestamp: $(date)"
print_info "Hostname: $(hostname)"
print_info "Log file: $LOG_FILE"
echo ""

#############################################
# Configuration
#############################################
K8S_VERSION="1.28"
POD_NETWORK_CIDR="192.168.0.0/16"
CALICO_VERSION="v3.27.0"
JOIN_COMMAND_FILE="/tmp/join-command.sh"

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

# Check Ubuntu version
print_info "Checking Ubuntu version..."
if [ -f /etc/os-release ]; then
    . /etc/os-release
    print_info "OS: $NAME $VERSION"
    if [[ "$VERSION_ID" != "25.04" ]]; then
        print_warning "This script is optimized for Ubuntu 25.04"
        print_warning "Current version: $VERSION_ID"
        read -p "Continue anyway? (yes/no): " CONTINUE
        if [ "$CONTINUE" != "yes" ]; then
            exit 1
        fi
    fi
else
    print_warning "Could not detect OS version"
fi

# Check if prerequisites are installed
print_info "Checking prerequisites..."

check_command() {
    if command -v $1 &> /dev/null; then
        print_success "$1 is installed ($(which $1))"
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
check_command containerd || PREREQ_OK=false

if [ "$PREREQ_OK" = false ]; then
    print_error "Prerequisites not installed. Please run prerequisites.sh first"
    exit 1
fi

# Check system resources
print_info "Checking system resources..."
TOTAL_CPU=$(nproc)
TOTAL_MEM_MB=$(free -m | awk '/^Mem:/{print $2}')

if [ "$TOTAL_CPU" -lt 2 ]; then
    print_warning "Recommended CPU cores: 2+, Available: $TOTAL_CPU"
else
    print_success "CPU cores: $TOTAL_CPU"
fi

if [ "$TOTAL_MEM_MB" -lt 4096 ]; then
    print_warning "Recommended memory: 4GB+, Available: ${TOTAL_MEM_MB}MB"
else
    print_success "Memory: ${TOTAL_MEM_MB}MB"
fi

# Check if swap is disabled
if [ "$(swapon -s | wc -l)" -gt 1 ]; then
    print_error "Swap is enabled. Kubernetes requires swap to be disabled."
    print_info "Run: sudo swapoff -a && sudo sed -i '/ swap / s/^/#/' /etc/fstab"
    exit 1
fi
print_success "Swap is disabled"

# Check if cluster already initialized
if [ -f /etc/kubernetes/admin.conf ]; then
    print_warning "Kubernetes cluster already initialized on this node"
    read -p "Do you want to reset and reinitialize? (yes/no): " RESET_CHOICE
    if [ "$RESET_CHOICE" = "yes" ]; then
        print_info "Resetting cluster..."
        kubeadm reset -f
        rm -rf /etc/kubernetes /var/lib/etcd ~/.kube
        print_success "Cluster reset complete"
    else
        print_info "Exiting without changes"
        exit 0
    fi
fi

#############################################
# Network Configuration
#############################################
print_header "Network Configuration"

# Get the node IP address
NODE_IP=$(hostname -I | awk '{print $1}')
print_info "Master Node IP: $NODE_IP"
print_info "Master Node Hostname: $(hostname)"

# Validate IP
if [[ ! $NODE_IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    print_error "Could not detect valid IP address"
    read -p "Please enter master node IP manually: " NODE_IP
fi

print_info "Using IP: $NODE_IP for API server"

#############################################
# Initialize Kubernetes Cluster
#############################################
print_header "Initializing Kubernetes Cluster"

print_info "Running kubeadm init..."
print_info "This may take a few minutes..."

kubeadm init \
    --pod-network-cidr=$POD_NETWORK_CIDR \
    --apiserver-advertise-address=$NODE_IP \
    --control-plane-endpoint=$NODE_IP:6443 \
    --kubernetes-version=stable-${K8S_VERSION} \
    --upload-certs \
    --v=5

print_success "Kubernetes cluster initialized successfully!"

#############################################
# Configure kubectl for root
#############################################
print_header "Configuring kubectl"

print_info "Setting up kubectl for root user..."
mkdir -p /root/.kube
cp -f /etc/kubernetes/admin.conf /root/.kube/config
chown root:root /root/.kube/config
print_success "kubectl configured for root"

# Configure for regular user if SUDO_USER exists
if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
    print_info "Setting up kubectl for user: $SUDO_USER..."
    USER_HOME=$(eval echo ~$SUDO_USER)
    sudo -u $SUDO_USER mkdir -p $USER_HOME/.kube
    cp -f /etc/kubernetes/admin.conf $USER_HOME/.kube/config
    chown $SUDO_USER:$SUDO_USER $USER_HOME/.kube/config
    print_success "kubectl configured for $SUDO_USER"
fi

# Verify kubectl access
print_info "Verifying kubectl access..."
if kubectl get nodes &> /dev/null; then
    print_success "kubectl is working correctly"
else
    print_error "kubectl access failed"
    exit 1
fi

#############################################
# Install Calico CNI
#############################################
print_header "Installing Calico CNI"

print_info "Downloading Calico operator..."
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/tigera-operator.yaml

print_info "Waiting for Tigera operator to be ready..."
sleep 10

print_info "Creating Calico custom resources..."
cat <<EOF | kubectl apply -f -
apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec:
  calicoNetwork:
    ipPools:
    - blockSize: 26
      cidr: ${POD_NETWORK_CIDR}
      encapsulation: VXLANCrossSubnet
      natOutgoing: Enabled
      nodeSelector: all()
---
apiVersion: operator.tigera.io/v1
kind: APIServer
metadata:
  name: default
spec: {}
EOF

print_success "Calico installation started"

print_info "Waiting for Calico pods to be ready (this may take 2-3 minutes)..."
sleep 30

# Wait for calico-system namespace
TIMEOUT=180
ELAPSED=0
while [ $ELAPSED -lt $TIMEOUT ]; do
    if kubectl get namespace calico-system &> /dev/null; then
        print_success "Calico namespace created"
        break
    fi
    sleep 5
    ELAPSED=$((ELAPSED + 5))
done

# Wait for Calico pods
print_info "Waiting for Calico pods to be running..."
kubectl wait --for=condition=Ready pods --all -n calico-system --timeout=300s || true
kubectl wait --for=condition=Ready pods --all -n tigera-operator --timeout=300s || true

print_success "Calico CNI installed successfully!"

#############################################
# Wait for Master Node to be Ready
#############################################
print_header "Waiting for Master Node"

print_info "Waiting for master node to be Ready..."
TIMEOUT=300
ELAPSED=0
while [ $ELAPSED -lt $TIMEOUT ]; do
    NODE_STATUS=$(kubectl get nodes -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}')
    if [ "$NODE_STATUS" = "True" ]; then
        print_success "Master node is Ready!"
        break
    fi
    echo -n "."
    sleep 5
    ELAPSED=$((ELAPSED + 5))
done

if [ "$NODE_STATUS" != "True" ]; then
    print_warning "Master node not ready yet, but continuing..."
fi

#############################################
# Generate Join Command
#############################################
print_header "Generating Worker Join Command"

print_info "Creating join token (valid for 24 hours)..."
JOIN_COMMAND=$(kubeadm token create --print-join-command)

# Save to file
echo "#!/bin/bash" > $JOIN_COMMAND_FILE
echo "# Generated on: $(date)" >> $JOIN_COMMAND_FILE
echo "# Master Node: $NODE_IP" >> $JOIN_COMMAND_FILE
echo "# Valid for: 24 hours" >> $JOIN_COMMAND_FILE
echo "" >> $JOIN_COMMAND_FILE
echo "$JOIN_COMMAND" >> $JOIN_COMMAND_FILE
chmod +x $JOIN_COMMAND_FILE

print_success "Join command generated and saved to: $JOIN_COMMAND_FILE"

#############################################
# Untaint Master (Optional)
#############################################
print_header "Master Node Configuration"

read -p "Allow pods to be scheduled on master node? (yes/no) [default: no]: " UNTAINT_MASTER
if [ "$UNTAINT_MASTER" = "yes" ]; then
    print_info "Removing master node taint..."
    kubectl taint nodes --all node-role.kubernetes.io/control-plane- || true
    kubectl taint nodes --all node-role.kubernetes.io/master- || true
    print_success "Master node can now schedule pods"
else
    print_info "Master node will only run control plane components (recommended)"
fi

#############################################
# Final Verification
#############################################
print_header "Cluster Status Verification"

print_info "Cluster Information:"
kubectl cluster-info

echo ""
print_info "Node Status:"
kubectl get nodes -o wide

echo ""
print_info "System Pods Status:"
kubectl get pods --all-namespaces -o wide

echo ""
print_info "Calico Status:"
kubectl get pods -n calico-system

#############################################
# Summary and Next Steps
#############################################
echo ""
print_header "Setup Complete!"
echo ""

print_success "Master node initialized successfully!"
print_info "Cluster Endpoint: https://$NODE_IP:6443"
print_info "Pod Network CIDR: $POD_NETWORK_CIDR"
print_info "CNI: Calico $CALICO_VERSION"
echo ""

print_header "Join Command for Worker Nodes"
echo ""
print_warning "Copy and run this command on WORKER nodes:"
echo ""
echo "----------------------------------------"
cat $JOIN_COMMAND_FILE | grep "kubeadm join"
echo "----------------------------------------"
echo ""

print_info "Join command also saved to: $JOIN_COMMAND_FILE"
echo ""

print_header "Useful Commands"
echo ""
echo "  # View cluster info"
echo "  kubectl cluster-info"
echo ""
echo "  # View nodes"
echo "  kubectl get nodes -o wide"
echo ""
echo "  # View all pods"
echo "  kubectl get pods --all-namespaces"
echo ""
echo "  # View Calico status"
echo "  kubectl get pods -n calico-system"
echo ""
echo "  # Generate new join command (if expired)"
echo "  kubeadm token create --print-join-command"
echo ""
echo "  # View cluster tokens"
echo "  kubeadm token list"
echo ""

print_header "Next Steps"
echo ""
print_info "1. Copy the join command from above"
print_info "2. Run prerequisites.sh on worker nodes"
print_info "3. Run worker-node.sh with join command on worker nodes"
print_info "4. Verify nodes joined: kubectl get nodes"
echo ""

print_success "Master node setup completed successfully!"
print_info "Log file: $LOG_FILE"
echo ""
