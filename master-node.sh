#!/bin/bash
#############################################
# Kubernetes Master Node Initialization Script
# Initializes the control plane and sets up networking
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

print_header "Kubernetes Master Node Initialization"
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
# Validate IP Address Function
#############################################
validate_ip() {
    local ip=$1
    local stat=1

    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
}

#############################################
# Get IP Address
#############################################
print_header "Determining Master Node IP Address"

if [ -n "$1" ]; then
    # IP provided as parameter
    MASTER_IP="$1"
    print_info "Using provided IP address: $MASTER_IP"
    
    if ! validate_ip "$MASTER_IP"; then
        print_error "Invalid IP address format: $MASTER_IP"
        print_info "Please provide a valid IP address"
        exit 1
    fi
else
    # Auto-detect primary IP
    print_info "Auto-detecting primary IP address..."
    
    # Try multiple methods to get IP
    MASTER_IP=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'src \K[^ ]+' || \
                hostname -I 2>/dev/null | awk '{print $1}' || \
                ip addr show | grep 'inet ' | grep -v '127.0.0.1' | head -1 | awk '{print $2}' | cut -d/ -f1)
    
    if [ -z "$MASTER_IP" ]; then
        print_error "Could not auto-detect IP address"
        print_info "Please run the script with IP address as parameter:"
        print_info "  sudo ./init-master.sh <ip-address>"
        exit 1
    fi
    
    print_warning "Detected IP address: $MASTER_IP"
    echo ""
    read -p "Is this correct? (y/n): " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_error "IP address not confirmed"
        print_info "Please run the script with correct IP address:"
        print_info "  sudo ./init-master.sh <ip-address>"
        exit 1
    fi
fi

print_success "Master IP confirmed: $MASTER_IP"
echo ""

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

# Check if cluster already exists
if [ -f "/etc/kubernetes/admin.conf" ]; then
    print_warning "Kubernetes cluster may already exist"
    read -p "Reset existing cluster? This will destroy all data! (y/n): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Resetting existing cluster..."
        kubeadm reset -f
        rm -rf /etc/kubernetes /var/lib/etcd ~/.kube
        print_success "Cluster reset complete"
    else
        print_error "Cannot proceed with existing cluster"
        print_info "Either reset the cluster or use existing configuration"
        exit 1
    fi
fi

echo ""

#############################################
# Initialize Kubernetes Cluster
#############################################
print_header "Initializing Kubernetes Cluster"
print_info "This may take 5-10 minutes..."
echo ""

# Create kubeadm config
cat <<EOF > /tmp/kubeadm-config.yaml
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
kubernetesVersion: stable
controlPlaneEndpoint: "${MASTER_IP}:6443"
networking:
  podSubnet: "192.168.0.0/16"
  serviceSubnet: "10.96.0.0/12"
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: ${MASTER_IP}
  bindPort: 6443
nodeRegistration:
  criSocket: unix:///var/run/containerd/containerd.sock
  taints:
  - effect: NoSchedule
    key: node-role.kubernetes.io/control-plane
EOF

print_section "Kubeadm Configuration"
cat /tmp/kubeadm-config.yaml
echo ""

print_section "Running kubeadm init..."
if kubeadm init --config=/tmp/kubeadm-config.yaml; then
    print_success "Kubernetes cluster initialized successfully"
else
    print_error "kubeadm init failed"
    print_info "Check logs with: journalctl -u kubelet -f"
    exit 1
fi

echo ""

#############################################
# Configure kubectl
#############################################
print_header "Configuring kubectl"

# Configure for root user
mkdir -p /root/.kube
cp -f /etc/kubernetes/admin.conf /root/.kube/config
chown root:root /root/.kube/config
print_success "kubectl configured for root user"

# Configure for current user if not root
if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
    USER_HOME=$(getent passwd $SUDO_USER | cut -d: -f6)
    mkdir -p $USER_HOME/.kube
    cp -f /etc/kubernetes/admin.conf $USER_HOME/.kube/config
    chown -R $SUDO_USER:$SUDO_USER $USER_HOME/.kube
    print_success "kubectl configured for user: $SUDO_USER"
fi

# Test kubectl access
if kubectl cluster-info &> /dev/null; then
    print_success "kubectl has cluster access"
else
    print_error "kubectl cannot access cluster"
    exit 1
fi

echo ""

#############################################
# Install Calico CNI
#############################################
print_header "Installing Calico CNI"
print_info "Installing Calico operator and custom resources..."

# Install Calico operator
print_section "Installing Tigera Operator"
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/tigera-operator.yaml

# Wait for operator to be ready
print_info "Waiting for Tigera operator to be ready..."
sleep 10

# Install Calico custom resources
print_section "Installing Calico Custom Resources"
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/custom-resources.yaml

print_success "Calico installation initiated"
echo ""

#############################################
# Wait for Control Plane Pods
#############################################
print_header "Waiting for Control Plane Components"

print_info "Waiting for system pods to be ready (this may take 2-3 minutes)..."

# Wait up to 5 minutes for all pods to be ready
TIMEOUT=300
ELAPSED=0
INTERVAL=10

while [ $ELAPSED -lt $TIMEOUT ]; do
    # Count total and running pods in kube-system
    TOTAL_PODS=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | wc -l)
    RUNNING_PODS=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | grep -c "Running" || echo "0")
    
    # Count Calico pods
    CALICO_TOTAL=$(kubectl get pods -n calico-system --no-headers 2>/dev/null | wc -l || echo "0")
    CALICO_RUNNING=$(kubectl get pods -n calico-system --no-headers 2>/dev/null | grep -c "Running" || echo "0")
    
    echo -ne "\r  kube-system: $RUNNING_PODS/$TOTAL_PODS running | calico-system: $CALICO_RUNNING/$CALICO_TOTAL running | Elapsed: ${ELAPSED}s"
    
    # Check if all critical pods are running
    if [ $TOTAL_PODS -gt 0 ] && [ $RUNNING_PODS -eq $TOTAL_PODS ] && [ $CALICO_TOTAL -gt 0 ] && [ $CALICO_RUNNING -eq $CALICO_TOTAL ]; then
        echo ""
        print_success "All system pods are running"
        break
    fi
    
    sleep $INTERVAL
    ELAPSED=$((ELAPSED + INTERVAL))
done

if [ $ELAPSED -ge $TIMEOUT ]; then
    echo ""
    print_warning "Timeout waiting for all pods to be ready"
    print_info "Some pods may still be starting. Check status with:"
    print_info "  kubectl get pods --all-namespaces"
fi

echo ""

#############################################
# Check Node Status
#############################################
print_header "Checking Node Status"

# Wait for node to be ready
NODE_READY=false
for i in {1..30}; do
    if kubectl get nodes | grep -q "Ready"; then
        NODE_READY=true
        break
    fi
    sleep 2
done

if [ "$NODE_READY" = true ]; then
    print_success "Master node is Ready"
    kubectl get nodes -o wide
else
    print_warning "Master node not yet Ready"
    print_info "Node may need a few more moments to be ready"
fi

echo ""

#############################################
# Generate Worker Join Command
#############################################
print_header "Generating Worker Join Command"

JOIN_COMMAND=$(kubeadm token create --print-join-command)

# Save to file
echo "#!/bin/bash" > /tmp/join-command.sh
echo "$JOIN_COMMAND" >> /tmp/join-command.sh
chmod +x /tmp/join-command.sh

print_success "Join command saved to: /tmp/join-command.sh"
echo ""
print_section "Worker Node Join Command:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "$JOIN_COMMAND"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

#############################################
# Display Cluster Information
#############################################
print_header "Cluster Information"

print_section "Cluster Endpoint"
print_info "API Server: https://${MASTER_IP}:6443"

echo ""
print_section "Kubernetes Version"
kubectl version --short 2>/dev/null | grep "Server Version" || kubectl version -o json | grep -A1 "serverVersion" | grep "gitVersion" | awk '{print $2}' | tr -d '","'

echo ""
print_section "System Pods Status"
kubectl get pods -n kube-system

echo ""
print_section "Calico Pods Status"
kubectl get pods -n calico-system 2>/dev/null || print_info "Calico pods may still be initializing..."

echo ""

#############################################
# Final Summary
#############################################
print_header "Initialization Complete!"
echo ""

print_success "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
print_success "  Master Node Successfully Initialized"
print_success "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

print_info "Next Steps:"
echo ""
echo "  1. Verify cluster health:"
echo "     sudo ./master-node.sh"
echo ""
echo "  2. Join worker nodes using this command:"
echo "     sudo ./worker-node.sh $JOIN_COMMAND"
echo ""
echo "  3. Or use the automated join script on worker nodes:"
echo "     sudo ./join-nodes.sh"
echo ""
echo "  4. Check cluster status:"
echo "     kubectl get nodes -o wide"
echo "     kubectl get pods --all-namespaces"
echo ""

print_info "Join command saved to: /tmp/join-command.sh"
print_info "Cluster endpoint: https://${MASTER_IP}:6443"
echo ""

print_warning "Important Notes:"
echo "  - Ensure worker nodes can reach ${MASTER_IP}:6443"
echo "  - Required ports must be open in firewall"
echo "  - Join command is valid for 24 hours"
echo ""

print_info "Initialization completed at $(date)"
echo ""
