# Kubernetes Cluster Setup - Usage Guide

## 🚀 Quick Start (Non-Interactive)

All scripts are now fully automated with no prompts. Just run them!

### **Master Node Setup:**
```bash
# Step 1: Install prerequisites
sudo ./prerequisites.sh

# Step 2: Reboot
sudo reboot

# Step 3: Initialize master (after reboot)
sudo ./master-node.sh
```

### **Worker Node Setup:**
```bash
# Step 1: Install prerequisites
sudo ./prerequisites.sh

# Step 2: Reboot
sudo reboot

# Step 3: Join cluster (after reboot)
# Get join command from master: cat /tmp/join-command.sh
sudo ./worker-node.sh kubeadm join 192.168.1.100:6443 --token abc... --discovery-token-ca-cert-hash sha256:xyz...
```

---

## 📋 Script Reference

### **1. prerequisites.sh**
Installs Kubernetes components on both master and worker nodes.

**Usage:**
```bash
# Basic (recommended)
sudo ./prerequisites.sh

# With custom options
sudo SKIP_VERSION_CHECK=true ./prerequisites.sh
```

**Environment Variables:**
- `SKIP_VERSION_CHECK` - Skip Ubuntu version check (default: false)

---

### **2. master-node.sh**
Initializes the Kubernetes control plane on the master node.

**Usage:**
```bash
# Basic (auto-detects everything)
sudo ./master-node.sh

# With custom configuration
sudo MASTER_IP=192.168.1.100 \
     ALLOW_MASTER_SCHEDULING=false \
     ./master-node.sh

# Reset and reinitialize existing cluster
sudo RESET_CLUSTER=true ./master-node.sh
```

**Environment Variables:**
- `MASTER_IP` - Master node IP address (default: auto-detected)
- `K8S_VERSION` - Kubernetes version (default: 1.28)
- `POD_NETWORK_CIDR` - Pod network CIDR (default: 192.168.0.0/16)
- `CALICO_VERSION` - Calico CNI version (default: v3.28.0)
- `SKIP_VERSION_CHECK` - Skip Ubuntu version check (default: false)
- `RESET_CLUSTER` - Reset existing cluster (default: false)
- `ALLOW_MASTER_SCHEDULING` - Allow pods on master (default: false)
- `JOIN_COMMAND_FILE` - Join command save location (default: /tmp/join-command.sh)

**Output:**
- Join command saved to: `/tmp/join-command.sh`
- Logs saved to: `/var/log/k8s-master-setup.log`

---

### **3. worker-node.sh**
Joins a worker node to the cluster.

**Usage:**
```bash
# Method 1: Provide join command as arguments
sudo ./worker-node.sh kubeadm join 192.168.1.100:6443 \
     --token abc123.xyz789 \
     --discovery-token-ca-cert-hash sha256:abcdef...

# Method 2: Use environment variable
sudo JOIN_COMMAND="kubeadm join 192.168.1.100:6443 --token abc..." \
     ./worker-node.sh

# Method 3: Get from master and use directly
sudo ./worker-node.sh $(ssh root@192.168.1.100 "cat /tmp/join-command.sh | grep kubeadm")
```

**Environment Variables:**
- `JOIN_COMMAND` - Full kubeadm join command
- `SKIP_VERSION_CHECK` - Skip Ubuntu version check (default: false)

---

### **4. join-nodes.sh**
Alternative to worker-node.sh with SSH auto-fetch capability.

**Usage:**
```bash
# Method 1: Provide join command
sudo ./join-nodes.sh kubeadm join 192.168.1.100:6443 --token abc...

# Method 2: Auto-fetch via SSH (requires SSH access to master)
sudo ./join-nodes.sh 192.168.1.100

# Method 3: With custom SSH user
sudo SSH_USER=ubuntu ./join-nodes.sh 192.168.1.100

# Method 4: Environment variable
sudo JOIN_COMMAND="kubeadm join..." ./join-nodes.sh

# Method 5: Reset and rejoin
sudo RESET_NODE=true ./join-nodes.sh 192.168.1.100
```

**Environment Variables:**
- `JOIN_COMMAND` - Full kubeadm join command
- `SSH_USER` - SSH user for master access (default: root)
- `RESET_NODE` - Reset before joining (default: false)
- `SKIP_VERSION_CHECK` - Skip Ubuntu version check (default: false)

---

### **5. verify-cluster.sh**
Verifies cluster health (already non-interactive).

**Usage:**
```bash
# Run on master node
sudo ./verify-cluster.sh
```

---

## 🎯 Complete Examples

### **Example 1: Basic Setup (Two VMs)**

**On Master VM (192.168.1.100):**
```bash
# Prerequisites
sudo ./prerequisites.sh
sudo reboot

# After reboot - Initialize master
sudo ./master-node.sh

# Copy join command
cat /tmp/join-command.sh
```

**On Worker VM (192.168.1.101):**
```bash
# Prerequisites
sudo ./prerequisites.sh
sudo reboot

# After reboot - Join cluster
sudo ./worker-node.sh kubeadm join 192.168.1.100:6443 --token abc123.xyz789 \
    --discovery-token-ca-cert-hash sha256:abcdef1234567890...
```

**Verify (on Master):**
```bash
kubectl get nodes -o wide
sudo ./verify-cluster.sh
```

---

### **Example 2: Custom Configuration**

**Master with custom settings:**
```bash
sudo MASTER_IP=192.168.1.100 \
     K8S_VERSION=1.28 \
     POD_NETWORK_CIDR=192.168.0.0/16 \
     ALLOW_MASTER_SCHEDULING=false \
     CALICO_VERSION=v3.28.0 \
     ./master-node.sh
```

---

### **Example 3: Automated via SSH**

**Worker with SSH auto-fetch:**
```bash
# Requires SSH key authentication to master
sudo ./join-nodes.sh 192.168.1.100

# Or with specific SSH user
sudo SSH_USER=ubuntu ./join-nodes.sh 192.168.1.100
```

---

### **Example 4: CI/CD Pipeline**

```bash
#!/bin/bash
# Automated cluster setup script

# Master node setup
export SKIP_VERSION_CHECK=true
export MASTER_IP=192.168.1.100
export ALLOW_MASTER_SCHEDULING=false

ssh root@192.168.1.100 "cd /root && ./prerequisites.sh && reboot"
sleep 60  # Wait for reboot
ssh root@192.168.1.100 "cd /root && ./master-node.sh"

# Get join command
JOIN_CMD=$(ssh root@192.168.1.100 "cat /tmp/join-command.sh | grep kubeadm")

# Worker node setup
ssh root@192.168.1.101 "cd /root && ./prerequisites.sh && reboot"
sleep 60  # Wait for reboot
ssh root@192.168.1.101 "cd /root && ./worker-node.sh $JOIN_CMD"

# Verify
ssh root@192.168.1.100 "kubectl get nodes"
```

---

## 🔧 Troubleshooting

### **Issue: Version check fails**
```bash
# Solution: Skip version check
sudo SKIP_VERSION_CHECK=true ./prerequisites.sh
sudo SKIP_VERSION_CHECK=true ./master-node.sh
```

### **Issue: Cluster already initialized**
```bash
# Solution: Reset and reinitialize
sudo RESET_CLUSTER=true ./master-node.sh
```

### **Issue: Node already joined**
```bash
# Solution: Reset and rejoin
sudo RESET_NODE=true ./join-nodes.sh 192.168.1.100
```

### **Issue: Cannot detect IP**
```bash
# Solution: Provide IP manually
sudo MASTER_IP=192.168.1.100 ./master-node.sh
```

### **Issue: Join command expired**
```bash
# Generate new token on master
kubeadm token create --print-join-command
```

---

## 📊 Configuration Summary

### **All Supported Environment Variables:**

```bash
# Common (all scripts)
SKIP_VERSION_CHECK=true|false    # Skip Ubuntu version check

# Master node only
MASTER_IP=<ip>                   # Master node IP address
K8S_VERSION=1.28                 # Kubernetes version
POD_NETWORK_CIDR=192.168.0.0/16  # Pod network CIDR
CALICO_VERSION=v3.28.0           # Calico version
RESET_CLUSTER=true|false         # Reset existing cluster
ALLOW_MASTER_SCHEDULING=true|false  # Allow pods on master
JOIN_COMMAND_FILE=/path/to/file  # Join command save location

# Worker node only
JOIN_COMMAND="kubeadm join..."   # Full join command
RESET_NODE=true|false            # Reset before joining
SSH_USER=root                    # SSH user for auto-fetch
```

---

## 🎓 Best Practices

1. **Always reboot** after prerequisites installation
2. **Test connectivity** between VMs before setup
3. **Use static IPs** for production clusters
4. **Save join command** immediately after master init
5. **Run verify-cluster.sh** after setup completion
6. **Keep logs** for troubleshooting (/var/log/k8s-*.log)
7. **Use environment variables** for automation
8. **Document your configuration** for reproducibility

---

## 📝 Script Execution Order

```
Both VMs:
1. prerequisites.sh → Install K8s components
2. reboot → Required!

Master VM:
3. master-node.sh → Initialize cluster
4. (Save join command from /tmp/join-command.sh)

Worker VM:
5. worker-node.sh or join-nodes.sh → Join cluster

Master VM:
6. verify-cluster.sh → Verify health
7. kubectl get nodes → Check status
```

---

## 🔐 Security Notes

- Scripts require root/sudo access
- Join tokens valid for 24 hours
- SSH keys required for auto-fetch
- TLS certificates auto-generated by kubeadm
- RBAC enabled by default

---

## 📚 Additional Resources

- **Setup Guide:** K8S-CLUSTER-SETUP.md
- **Kubernetes Docs:** https://kubernetes.io/docs/
- **Calico Docs:** https://docs.tigera.io/calico/
- **kubeadm Reference:** https://kubernetes.io/docs/reference/setup-tools/kubeadm/

---

**Last Updated:** October 25, 2025  
**Kubernetes Version:** 1.28  
**Calico Version:** 3.28.0  
**Supported OS:** Ubuntu 24.04, 22.04, 20.04 LTS
