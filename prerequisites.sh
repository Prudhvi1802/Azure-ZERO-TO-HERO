#!/bin/bash
#############################################
# Kubernetes Prerequisites Setup Script
# Run this on BOTH master and worker nodes
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

print_info "=========================================="
print_info "Kubernetes Prerequisites Installation"
print_info "Run this on BOTH master and worker nodes"
print_info "=========================================="

# 1. Disable automatic updates (prevents interruptions)
sudo systemctl stop unattended-upgrades
sudo systemctl disable unattended-upgrades

# 2. Kill any running apt processes
sudo killall apt apt-get dpkg 2>/dev/null || true

# 3. Wait a moment
sleep 3

# 4. Clean up locks
sudo rm -f /var/lib/apt/lists/lock
sudo rm -f /var/cache/apt/archives/lock
sudo rm -f /var/lib/dpkg/lock*

# 5. Fix any interrupted installations
sudo dpkg --configure -a

# 6. Update system manually
sudo apt-get update
sudo apt-get upgrade

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    print_error "Please run as root (use sudo)"
    exit 1
fi

print_info "System: $(lsb_release -d | cut -f2)"
print_info "Kernel: $(uname -r)"

# Verify Ubuntu version (non-interactive)
SKIP_VERSION_CHECK=${SKIP_VERSION_CHECK:-false}

if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [[ "$VERSION_ID" != "24.04" ]] && [[ "$VERSION_ID" != "22.04" ]] && [[ "$VERSION_ID" != "20.04" ]]; then
        if [[ "$SKIP_VERSION_CHECK" == "true" ]]; then
            print_warning "Ubuntu $VERSION_ID detected. Continuing anyway (SKIP_VERSION_CHECK=true)"
        else
            print_warning "Ubuntu $VERSION_ID detected. Recommended: 24.04, 22.04, or 20.04 LTS"
            print_warning "Set SKIP_VERSION_CHECK=true to bypass this check"
            print_info "Continuing with current version..."
        fi
    else
        print_success "Ubuntu $VERSION_ID detected"
    fi
fi

# Update system
print_info "Updating system packages..."
apt-get update
apt-get upgrade
print_success "System updated"

# Install required packages
print_info "Installing required packages..."
apt-get install \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common \
    net-tools \
    git
print_success "Required packages installed"

# Disable swap (required for Kubernetes)
print_info "Disabling swap..."
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab
print_success "Swap disabled"

# Load kernel modules
print_info "Loading kernel modules..."
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter
print_success "Kernel modules loaded"

# Configure sysctl
print_info "Configuring sysctl parameters..."
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system
print_success "Sysctl configured"

# Install containerd
print_info "Installing containerd..."
apt-get install containerd

# Configure containerd
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml

# Set SystemdCgroup to true
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# Restart containerd
systemctl restart containerd
systemctl enable containerd
print_success "Containerd installed and configured"

# Add Kubernetes repository
print_info "Adding Kubernetes repository..."
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list

apt-get update
print_success "Kubernetes repository added"

# Install Kubernetes components
print_info "Installing kubelet, kubeadm, and kubectl..."
apt-get install kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

systemctl enable kubelet
systemctl start kubelet
print_success "Kubernetes components installed"

# Verify installation
print_info ""
print_info "=========================================="
print_info "Installation Complete!"
print_info "=========================================="
print_info ""
print_info "Installed versions:"
echo -n "  - kubelet: "
kubelet --version
echo -n "  - kubeadm: "
kubeadm version -o short
echo -n "  - kubectl: "
kubectl version --client -o yaml | grep gitVersion | head -1 | awk '{print $2}'
echo -n "  - containerd: "
containerd --version | awk '{print $3}'

print_info ""
print_success "Prerequisites installation completed successfully!"
print_info ""
print_info "Next steps:"
print_info "  - On MASTER node: Run ./setup-master-node.sh"
print_info "  - On WORKER node: Run ./setup-worker-node.sh <join-command>"
print_info ""
