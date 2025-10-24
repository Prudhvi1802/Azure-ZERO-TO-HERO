# Kubernetes Multi-VM Cluster Setup Guide

Complete guide for setting up a production-ready Kubernetes cluster across multiple VMs using kubeadm with Calico CNI.

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [VM Requirements](#vm-requirements)
- [Network Requirements](#network-requirements)
- [Setup Instructions](#setup-instructions)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)
- [Useful Commands](#useful-commands)

## 🎯 Overview

This setup creates a production-like Kubernetes cluster with:
- **Multi-VM Architecture**: Separate master (control plane) and worker nodes
- **Calico CNI**: Advanced networking with network policies
- **kubeadm**: Official Kubernetes cluster bootstrapping tool
- **Containerd**: Industry-standard container runtime
- **Ubuntu 25.04**: Latest LTS support

### Cluster Specifications

| Component | Version | Details |
|-----------|---------|---------|
| Kubernetes | 1.28.x | Stable release |
| CNI | Calico 3.27.0 | Pod network CIDR: 192.168.0.0/16 |
| Container Runtime | containerd | SystemdCgroup enabled |
| OS | Ubuntu 25.04 LTS | Production-ready |

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                        │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌─────────────────────┐        ┌─────────────────────┐    │
│  │   Master Node VM    │        │   Worker Node VM    │    │
│  │  (Control Plane)    │◄──────►│   (Data Plane)      │    │
│  │                     │        │                     │    │
│  │ ┌─────────────────┐ │        │ ┌─────────────────┐ │    │
│  │ │ API Server      │ │        │ │ kubelet         │ │    │
│  │ │ etcd            │ │        │ │ kube-proxy      │ │    │
│  │ │ Controller Mgr  │ │        │ │ containerd      │ │    │
│  │ │ Scheduler       │ │        │ │ Calico Node     │ │    │
│  │ └─────────────────┘ │        │ └─────────────────┘ │    │
│  │                     │        │                     │    │
│  │ Calico Controller   │        │   Your Pods Here    │    │
│  └─────────────────────┘        └─────────────────────┘    │
│                                                               │
│  Pod Network: 192.168.0.0/16                                │
└─────────────────────────────────────────────────────────────┘
```

## ✅ Prerequisites

### Required for Both VMs

- **Operating System**: Ubuntu 25.04 LTS (or 20.04/22.04 compatible)
- **Root Access**: sudo privileges required
- **Network**: Static IP addresses (recommended)
- **Internet**: Required for downloading packages

### Software Components (Installed by scripts)

- containerd (container runtime)
- kubeadm, kubelet, kubectl (Kubernetes tools)
- Calico CNI (networking)

## 💻 VM Requirements

### Master Node (Control Plane)

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| CPU | 2 cores | 4+ cores |
| Memory | 4 GB RAM | 8+ GB RAM |
| Disk | 20 GB | 50+ GB |
| Network | 1 NIC | 1+ NIC |

### Worker Node(s)

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| CPU | 2 cores | 4+ cores |
| Memory | 2 GB RAM | 8+ GB RAM |
| Disk | 20 GB | 50+ GB |
| Network | 1 NIC | 1+ NIC |

## 🌐 Network Requirements

### Required Ports - Master Node

| Port Range | Protocol | Purpose |
|------------|----------|---------|
| 6443 | TCP | Kubernetes API server |
| 2379-2380 | TCP | etcd server client API |
| 10250 | TCP | Kubelet API |
| 10251 | TCP | kube-scheduler |
| 10252 | TCP | kube-controller-manager |
| 10257 | TCP | kube-controller-manager (secure) |
| 10259 | TCP | kube-scheduler (secure) |

### Required Ports - Worker Node

| Port Range | Protocol | Purpose |
|------------|----------|---------|
| 10250 | TCP | Kubelet API |
| 30000-32767 | TCP | NodePort Services |

### Required Ports - Calico

| Port | Protocol | Purpose |
|------|----------|---------|
| 179 | TCP | BGP |
| 4789 | UDP | VXLAN |
| 5473 | TCP | Typha (if used) |

### Network Configuration Checklist

- [ ] VMs can ping each other
- [ ] Firewall rules allow required ports
- [ ] No NAT between master and worker nodes
- [ ] Static IP addresses configured (recommended)
- [ ] DNS resolution working

## 🚀 Setup Instructions

### Step 1: Prepare Both VMs

Run these commands on **BOTH** master and worker nodes:

```bash
# Download or clone the repository
cd /opt
git clone <your-repo-url> k8s-setup
cd k8s-setup

# Make scripts executable
chmod +x prerequisites.sh master-node.sh worker-node.sh join-nodes.sh verify-cluster.sh

# Run prerequisites installation
sudo ./prerequisites.sh
```

**Expected Output:**
- All required packages installed
- Swap disabled
- Kernel modules loaded
- Container runtime configured

**⚠️ Important:** Reboot both VMs after prerequisites installation:
```bash
sudo reboot
```

### Step 2: Initialize Master Node

Run this on the **MASTER NODE ONLY**:

```bash
# After reboot, run master node setup
sudo ./master-node.sh
```

**What happens:**
1. Pre-flight checks validate prerequisites
2. Kubernetes cluster initialized with kubeadm
3. kubectl configured for cluster access
4. Calico CNI installed and configured
5. Join command generated and saved

**Expected Duration:** 5-10 minutes

**Important Outputs:**
- Cluster endpoint: `https://<master-ip>:6443`
- Join command saved to: `/tmp/join-command.sh`
- Master node status: Ready

**Copy the join command** displayed at the end. It looks like:
```bash
kubeadm join 192.168.1.100:6443 --token abc123.xyz789 \
    --discovery-token-ca-cert-hash sha256:1234567890abcdef...
```

### Step 3: Join Worker Node

Run this on the **WORKER NODE(S)**:

**Option A: Using worker-node.sh (Manual)**
```bash
# Paste the join command from master as argument
sudo ./worker-node.sh kubeadm join 192.168.1.100:6443 --token abc123.xyz789 \
    --discovery-token-ca-cert-hash sha256:1234567890abcdef...
```

**Option B: Using join-nodes.sh (Automated)**
```bash
# Interactive mode - will prompt for join command
sudo ./join-nodes.sh

# OR provide master IP (requires SSH access to master)
sudo ./join-nodes.sh <master-ip>

# OR provide full join command
sudo ./join-nodes.sh kubeadm join 192.168.1.100:6443 --token ...
```

**Expected Duration:** 2-5 minutes

### Step 4: Verify Cluster

Run on the **MASTER NODE**:

```bash
# Quick verification
kubectl get nodes -o wide

# Comprehensive verification
sudo ./verify-cluster.sh
```

**Expected Output:**
```
NAME            STATUS   ROLES           AGE   VERSION
master-node     Ready    control-plane   10m   v1.28.x
worker-node-1   Ready    <none>          5m    v1.28.x
```

**All nodes should show `Ready` status within 1-2 minutes.**

## ✅ Verification

### Basic Health Checks

```bash
# Check nodes
kubectl get nodes -o wide

# Check system pods
kubectl get pods --all-namespaces

# Check Calico
kubectl get pods -n calico-system

# Check cluster info
kubectl cluster-info

# Run comprehensive verification
sudo ./verify-cluster.sh
```

### Expected Results

✓ All nodes in `Ready` state  
✓ All system pods `Running`  
✓ All Calico pods `Running`  
✓ CoreDNS pods `Running`  
✓ API server accessible  

### Test Pod Deployment

```bash
# Create a test deployment
kubectl create deployment nginx --image=nginx --replicas=2

# Check pods
kubectl get pods -o wide

# Expose as service
kubectl expose deployment nginx --port=80 --type=NodePort

# Get service details
kubectl get svc nginx

# Test connectivity (from any node)
curl http://<node-ip>:<node-port>
```

## 🔧 Troubleshooting

### Node Not Ready

**Check kubelet status:**
```bash
systemctl status kubelet
journalctl -u kubelet -f
```

**Common Issues:**
- CNI not installed → Check Calico pods: `kubectl get pods -n calico-system`
- Container runtime issues → Check containerd: `systemctl status containerd`
- Network configuration → Verify firewall rules

### Pods Stuck in Pending

**Check reasons:**
```bash
kubectl describe pod <pod-name>
kubectl get events --sort-by='.lastTimestamp'
```

**Common Causes:**
- Insufficient resources
- Node selector/affinity issues
- PersistentVolume issues
- Network policies blocking traffic

### Join Command Failed

**Generate new token (on master):**
```bash
kubeadm token create --print-join-command
```

**Reset worker node (if needed):**
```bash
sudo kubeadm reset -f
sudo rm -rf /etc/kubernetes /var/lib/kubelet
# Then retry join
```

### Calico Pods Not Running

**Check Calico logs:**
```bash
kubectl logs -n calico-system <calico-pod-name>
kubectl logs -n tigera-operator <operator-pod-name>
```

**Restart Calico (if needed):**
```bash
kubectl delete pods -n calico-system --all
kubectl delete pods -n tigera-operator --all
```

### Network Connectivity Issues

**Test pod-to-pod:**
```bash
# Create test pods
kubectl run test-1 --image=busybox --command -- sleep 3600
kubectl run test-2 --image=busybox --command -- sleep 3600

# Get IPs
kubectl get pods -o wide

# Test ping from test-1 to test-2
kubectl exec test-1 -- ping <test-2-ip>
```

**Check Calico node status:**
```bash
# On each node
sudo calicoctl node status
```

### Complete Cluster Reset

**On master:**
```bash
sudo kubeadm reset -f
sudo rm -rf /etc/kubernetes /var/lib/etcd ~/.kube
```

**On worker:**
```bash
sudo kubeadm reset -f
sudo rm -rf /etc/kubernetes /var/lib/kubelet ~/.kube
```

Then re-run setup scripts.

## 📝 Useful Commands

### Cluster Management

```bash
# View cluster info
kubectl cluster-info
kubectl cluster-info dump

# View all resources
kubectl get all --all-namespaces

# View nodes with details
kubectl get nodes -o wide
kubectl describe node <node-name>

# View cluster events
kubectl get events --all-namespaces --sort-by='.lastTimestamp'
```

### Pod Management

```bash
# List pods
kubectl get pods --all-namespaces
kubectl get pods -n <namespace> -o wide

# Describe pod
kubectl describe pod <pod-name> -n <namespace>

# View logs
kubectl logs <pod-name> -n <namespace>
kubectl logs -f <pod-name> -n <namespace>

# Execute command in pod
kubectl exec -it <pod-name> -n <namespace> -- /bin/bash
```

### Token Management

```bash
# List tokens
kubeadm token list

# Create new token
kubeadm token create --print-join-command

# Delete token
kubeadm token delete <token>
```

### Node Management

```bash
# Drain node (before maintenance)
kubectl drain <node-name> --ignore-daemonsets

# Uncordon node (after maintenance)
kubectl uncordon <node-name>

# Delete node (from cluster)
kubectl delete node <node-name>

# Label nodes
kubectl label nodes <node-name> <key>=<value>
```

### Calico Management

```bash
# Check Calico status
kubectl get pods -n calico-system
kubectl get pods -n tigera-operator

# View Calico configuration
kubectl get installation default -o yaml
kubectl get ippools -o yaml

# Check Calico node status (on node)
sudo calicoctl node status
```

### Debugging

```bash
# Check kubelet logs
journalctl -u kubelet -f

# Check containerd logs
journalctl -u containerd -f

# Check system logs
tail -f /var/log/syslog

# Run diagnostic pod
kubectl run debug --image=busybox --command -- sleep 3600
kubectl exec -it debug -- /bin/sh
```

## 🎓 Best Practices

### Security

- ✓ Use RBAC for access control
- ✓ Enable Pod Security Standards
- ✓ Use Network Policies
- ✓ Regular security updates
- ✓ Secure etcd with TLS
- ✓ Rotate tokens regularly

### High Availability

- Add multiple master nodes (HA setup)
- Use external etcd cluster
- Implement load balancer for API server
- Regular backups of etcd

### Monitoring

- Install metrics-server: `kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml`
- Use Prometheus + Grafana for monitoring
- Set up logging (ELK/EFK stack)

### Maintenance

- Regular cluster upgrades
- Monitor resource usage
- Clean up unused resources
- Regular etcd backups

## 📚 Additional Resources

- [Official Kubernetes Documentation](https://kubernetes.io/docs/)
- [Calico Documentation](https://docs.tigera.io/calico/latest/about/)
- [kubeadm Documentation](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)

## 📜 Script Reference

| Script | Purpose | Run On |
|--------|---------|--------|
| `prerequisites.sh` | Install all prerequisites | Both nodes |
| `master-node.sh` | Initialize master node | Master only |
| `worker-node.sh` | Join worker to cluster | Worker only |
| `join-nodes.sh` | Automated worker join | Worker only |
| `verify-cluster.sh` | Verify cluster health | Master only |

## 🐛 Common Issues

### Issue: "The connection to the server localhost:8080 was refused"

**Solution:** kubectl not configured
```bash
mkdir -p ~/.kube
sudo cp /etc/kubernetes/admin.conf ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
```

### Issue: Node remains in "NotReady" state

**Solution:** Wait for CNI installation or check Calico:
```bash
kubectl get pods -n calico-system
kubectl get pods -n tigera-operator
```

### Issue: Token expired

**Solution:** Generate new token on master:
```bash
kubeadm token create --print-join-command
```

## 📄 License

This setup guide and scripts are provided as-is for educational and production use.

---

**Last Updated:** October 2025  
**Kubernetes Version:** 1.28.x  
**Calico Version:** 3.27.0  
**Ubuntu Version:** 25.04 LTS
