# Kubernetes Cluster - Firewall & Port Configuration

## 📋 Required Ports Reference Guide

This document lists all required ports for your Kubernetes cluster and provides firewall configuration commands.

---

## 🔐 Port Requirements Overview

### **Master Node (Control Plane)**
All ports below must be open on the master node:

| Port/Protocol | Service | Direction | Purpose |
|--------------|---------|-----------|---------|
| **6443/TCP** | kube-apiserver | Inbound | Kubernetes API Server |
| **2379-2380/TCP** | etcd | Inbound | etcd server client API |
| **10250/TCP** | kubelet | Inbound | Kubelet API |
| **10257/TCP** | kube-controller-manager | Inbound | Controller Manager |
| **10259/TCP** | kube-scheduler | Inbound | Scheduler |
| **179/TCP** | Calico | Bidirectional | Calico BGP networking |
| **4789/UDP** | Calico | Bidirectional | Calico VXLAN networking |
| **Protocol 4** | Calico | Bidirectional | IP-in-IP (if used) |

### **Worker Nodes**
All ports below must be open on worker nodes:

| Port/Protocol | Service | Direction | Purpose |
|--------------|---------|-----------|---------|
| **10250/TCP** | kubelet | Inbound | Kubelet API |
| **30000-32767/TCP** | NodePort Services | Inbound | NodePort Services Range |
| **179/TCP** | Calico | Bidirectional | Calico BGP networking |
| **4789/UDP** | Calico | Bidirectional | Calico VXLAN networking |
| **Protocol 4** | Calico | Bidirectional | IP-in-IP (if used) |

### **Optional Ports** (if needed)

| Port/Protocol | Service | When Needed |
|--------------|---------|-------------|
| **22/TCP** | SSH | For join-nodes.sh auto-fetch or remote management |
| **80/TCP** | HTTP | For HTTP ingress traffic |
| **443/TCP** | HTTPS | For HTTPS ingress traffic |
| **8080/TCP** | Kubectl proxy | For kubectl proxy access |

---

## 🚀 Quick Start - Open All Required Ports

### **For Master Node:**

```bash
# Run this on MASTER node
sudo ufw allow 6443/tcp comment "Kubernetes API Server"
sudo ufw allow 2379:2380/tcp comment "etcd server"
sudo ufw allow 10250/tcp comment "Kubelet API"
sudo ufw allow 10257/tcp comment "kube-controller-manager"
sudo ufw allow 10259/tcp comment "kube-scheduler"
sudo ufw allow 179/tcp comment "Calico BGP"
sudo ufw allow 4789/udp comment "Calico VXLAN"

# Enable firewall
sudo ufw enable
sudo ufw status
```

### **For Worker Node:**

```bash
# Run this on WORKER node
sudo ufw allow 10250/tcp comment "Kubelet API"
sudo ufw allow 30000:32767/tcp comment "NodePort Services"
sudo ufw allow 179/tcp comment "Calico BGP"
sudo ufw allow 4789/udp comment "Calico VXLAN"

# Enable firewall
sudo ufw enable
sudo ufw status
```

---

## 🔧 Detailed Firewall Configuration

### **Method 1: UFW (Ubuntu Firewall) - Recommended**

#### **Master Node UFW Configuration:**

```bash
#!/bin/bash
# Master Node Firewall Configuration

# Reset UFW (optional - only if starting fresh)
# sudo ufw --force reset

# Set default policies
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH (important - don't lock yourself out!)
sudo ufw allow 22/tcp comment "SSH"

# Kubernetes Control Plane Ports
sudo ufw allow 6443/tcp comment "Kubernetes API Server"
sudo ufw allow 2379:2380/tcp comment "etcd server client API"
sudo ufw allow 10250/tcp comment "Kubelet API"
sudo ufw allow 10257/tcp comment "kube-controller-manager"
sudo ufw allow 10259/tcp comment "kube-scheduler"

# Calico CNI Ports
sudo ufw allow 179/tcp comment "Calico BGP"
sudo ufw allow 4789/udp comment "Calico VXLAN"

# Optional: Allow from specific worker IP only
# sudo ufw allow from 192.168.1.101 to any port 6443 proto tcp

# Enable UFW
sudo ufw --force enable

# Check status
sudo ufw status numbered
```

#### **Worker Node UFW Configuration:**

```bash
#!/bin/bash
# Worker Node Firewall Configuration

# Reset UFW (optional)
# sudo ufw --force reset

# Set default policies
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH
sudo ufw allow 22/tcp comment "SSH"

# Kubernetes Worker Ports
sudo ufw allow 10250/tcp comment "Kubelet API"
sudo ufw allow 30000:32767/tcp comment "NodePort Services"

# Calico CNI Ports
sudo ufw allow 179/tcp comment "Calico BGP"
sudo ufw allow 4789/udp comment "Calico VXLAN"

# Optional: Allow from specific master IP only
# sudo ufw allow from 192.168.1.100 to any port 10250 proto tcp

# Enable UFW
sudo ufw --force enable

# Check status
sudo ufw status numbered
```

---

### **Method 2: iptables (Advanced)**

#### **Master Node iptables:**

```bash
#!/bin/bash
# Master Node iptables Configuration

# Flush existing rules (careful!)
# sudo iptables -F

# Allow established connections
sudo iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Allow loopback
sudo iptables -A INPUT -i lo -j ACCEPT

# Allow SSH
sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# Kubernetes Control Plane
sudo iptables -A INPUT -p tcp --dport 6443 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 2379:2380 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 10250 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 10257 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 10259 -j ACCEPT

# Calico
sudo iptables -A INPUT -p tcp --dport 179 -j ACCEPT
sudo iptables -A INPUT -p udp --dport 4789 -j ACCEPT
sudo iptables -A INPUT -p 4 -j ACCEPT  # IP-in-IP

# Default policy
sudo iptables -P INPUT DROP
sudo iptables -P FORWARD DROP
sudo iptables -P OUTPUT ACCEPT

# Save rules
sudo apt-get install -y iptables-persistent
sudo netfilter-persistent save
```

#### **Worker Node iptables:**

```bash
#!/bin/bash
# Worker Node iptables Configuration

# Allow established connections
sudo iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Allow loopback
sudo iptables -A INPUT -i lo -j ACCEPT

# Allow SSH
sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# Kubernetes Worker
sudo iptables -A INPUT -p tcp --dport 10250 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 30000:32767 -j ACCEPT

# Calico
sudo iptables -A INPUT -p tcp --dport 179 -j ACCEPT
sudo iptables -A INPUT -p udp --dport 4789 -j ACCEPT
sudo iptables -A INPUT -p 4 -j ACCEPT  # IP-in-IP

# Default policy
sudo iptables -P INPUT DROP
sudo iptables -P FORWARD DROP
sudo iptables -P OUTPUT ACCEPT

# Save rules
sudo apt-get install -y iptables-persistent
sudo netfilter-persistent save
```

---

### **Method 3: firewalld (RHEL/CentOS)**

#### **Master Node firewalld:**

```bash
#!/bin/bash
# Master Node firewalld Configuration

# Start firewalld
sudo systemctl start firewalld
sudo systemctl enable firewalld

# Kubernetes Control Plane
sudo firewall-cmd --permanent --add-port=6443/tcp
sudo firewall-cmd --permanent --add-port=2379-2380/tcp
sudo firewall-cmd --permanent --add-port=10250/tcp
sudo firewall-cmd --permanent --add-port=10257/tcp
sudo firewall-cmd --permanent --add-port=10259/tcp

# Calico
sudo firewall-cmd --permanent --add-port=179/tcp
sudo firewall-cmd --permanent --add-port=4789/udp

# Reload
sudo firewall-cmd --reload

# Check
sudo firewall-cmd --list-all
```

#### **Worker Node firewalld:**

```bash
#!/bin/bash
# Worker Node firewalld Configuration

# Start firewalld
sudo systemctl start firewalld
sudo systemctl enable firewalld

# Kubernetes Worker
sudo firewall-cmd --permanent --add-port=10250/tcp
sudo firewall-cmd --permanent --add-port=30000-32767/tcp

# Calico
sudo firewall-cmd --permanent --add-port=179/tcp
sudo firewall-cmd --permanent --add-port=4789/udp

# Reload
sudo firewall-cmd --reload

# Check
sudo firewall-cmd --list-all
```

---

## 🔍 Testing Port Connectivity

### **Test from Worker to Master:**

```bash
# Test Kubernetes API Server (most important)
telnet 192.168.1.100 6443
# Or
nc -zv 192.168.1.100 6443

# Test all master ports
for port in 6443 2379 2380 10250 10257 10259 179; do
    echo "Testing port $port..."
    nc -zv 192.168.1.100 $port
done

# Test UDP port (Calico VXLAN)
nc -uzv 192.168.1.100 4789
```

### **Test from Master to Worker:**

```bash
# Test Kubelet API
nc -zv 192.168.1.101 10250

# Test Calico BGP
nc -zv 192.168.1.101 179

# Test NodePort range (example)
nc -zv 192.168.1.101 30000
```

### **Comprehensive Port Check Script:**

```bash
#!/bin/bash
# Save as: check-ports.sh

MASTER_IP="192.168.1.100"
WORKER_IP="192.168.1.101"

echo "=== Testing Master Ports ==="
for port in 6443 2379 2380 10250 10257 10259 179; do
    if nc -zv -w5 $MASTER_IP $port 2>&1 | grep -q succeeded; then
        echo "✓ Port $port - OPEN"
    else
        echo "✗ Port $port - CLOSED"
    fi
done

echo ""
echo "=== Testing Worker Ports ==="
for port in 10250 179 30000; do
    if nc -zv -w5 $WORKER_IP $port 2>&1 | grep -q succeeded; then
        echo "✓ Port $port - OPEN"
    else
        echo "✗ Port $port - CLOSED"
    fi
done
```

---

## 🛡️ Security Best Practices

### **1. Restrict Source IPs (Recommended)**

**Allow only specific IPs instead of 0.0.0.0/0:**

```bash
# On Master: Allow API access only from worker IPs
sudo ufw delete allow 6443/tcp
sudo ufw allow from 192.168.1.101 to any port 6443 proto tcp

# On Worker: Allow kubelet access only from master IP
sudo ufw delete allow 10250/tcp
sudo ufw allow from 192.168.1.100 to any port 10250 proto tcp
```

### **2. Use Private Network**

**Ensure all Kubernetes traffic stays on private network:**
- Use private IPs (10.x.x.x, 192.168.x.x, 172.16.x.x)
- Don't expose Kubernetes ports to public internet
- Use VPN for external access

### **3. Minimal Exposure**

**Only open required ports:**
```bash
# ✅ Good: Specific ports
sudo ufw allow 6443/tcp

# ❌ Bad: Too broad
sudo ufw allow 6000:7000/tcp
```

### **4. Monitor Traffic**

```bash
# Watch connections to API server
sudo watch -n 2 'netstat -an | grep :6443'

# Check UFW logs
sudo tail -f /var/log/ufw.log

# List active connections
sudo ss -tunlp | grep -E '6443|10250|2379'
```

---

## 🚨 Troubleshooting

### **Issue: Cannot connect to API server**

```bash
# Check if port is open
sudo ufw status | grep 6443

# Check if API server is listening
sudo netstat -tlnp | grep 6443

# Check from worker
telnet master-ip 6443

# Temporarily disable firewall for testing
sudo ufw disable
# Try connection
# Re-enable
sudo ufw enable
```

### **Issue: Pods not communicating across nodes**

```bash
# Check Calico ports
sudo ufw status | grep -E '179|4789'

# Check if Calico is running
kubectl get pods -n calico-system

# Test Calico connectivity
kubectl exec -it <pod> -- ping <other-pod-ip>
```

### **Issue: NodePort services not accessible**

```bash
# Check if range is open
sudo ufw status | grep 30000:32767

# Test specific NodePort
curl http://worker-ip:32000

# Check service
kubectl get svc -o wide
```

---

## 📊 Port Summary Table

### **Master Node - Complete List:**

```
Protocol | Port(s)      | Service                  | Required
---------|--------------|--------------------------|----------
TCP      | 22           | SSH (management)         | Optional
TCP      | 6443         | API Server              | ✓ Yes
TCP      | 2379-2380    | etcd                    | ✓ Yes
TCP      | 10250        | Kubelet API             | ✓ Yes
TCP      | 10257        | Controller Manager      | ✓ Yes
TCP      | 10259        | Scheduler               | ✓ Yes
TCP      | 179          | Calico BGP              | ✓ Yes
UDP      | 4789         | Calico VXLAN            | ✓ Yes
IP-in-IP | Protocol 4   | Calico IP-in-IP         | Optional
TCP      | 80           | HTTP Ingress            | Optional
TCP      | 443          | HTTPS Ingress           | Optional
```

### **Worker Node - Complete List:**

```
Protocol | Port(s)      | Service                  | Required
---------|--------------|--------------------------|----------
TCP      | 22           | SSH (management)         | Optional
TCP      | 10250        | Kubelet API             | ✓ Yes
TCP      | 30000-32767  | NodePort Services       | ✓ Yes
TCP      | 179          | Calico BGP              | ✓ Yes
UDP      | 4789         | Calico VXLAN            | ✓ Yes
IP-in-IP | Protocol 4   | Calico IP-in-IP         | Optional
TCP      | 80           | HTTP Ingress            | Optional
TCP      | 443          | HTTPS Ingress           | Optional
```

---

## 🎯 Recommended Firewall Scripts

### **Create: master-firewall.sh**

```bash
#!/bin/bash
# Master Node Firewall Setup
# Usage: sudo ./master-firewall.sh

echo "Configuring Master Node Firewall..."

# Reset UFW
sudo ufw --force disable
sudo ufw --force reset

# Default policies
sudo ufw default deny incoming
sudo ufw default allow outgoing

# SSH - IMPORTANT!
sudo ufw allow 22/tcp

# Kubernetes Control Plane
sudo ufw allow 6443/tcp
sudo ufw allow 2379:2380/tcp
sudo ufw allow 10250/tcp
sudo ufw allow 10257/tcp
sudo ufw allow 10259/tcp

# Calico
sudo ufw allow 179/tcp
sudo ufw allow 4789/udp

# Enable
sudo ufw --force enable

echo "✓ Master Node Firewall Configured"
sudo ufw status numbered
```

### **Create: worker-firewall.sh**

```bash
#!/bin/bash
# Worker Node Firewall Setup
# Usage: sudo ./worker-firewall.sh

echo "Configuring Worker Node Firewall..."

# Reset UFW
sudo ufw --force disable
sudo ufw --force reset

# Default policies
sudo ufw default deny incoming
sudo ufw default allow outgoing

# SSH - IMPORTANT!
sudo ufw allow 22/tcp

# Kubernetes Worker
sudo ufw allow 10250/tcp
sudo ufw allow 30000:32767/tcp

# Calico
sudo ufw allow 179/tcp
sudo ufw allow 4789/udp

# Enable
sudo ufw --force enable

echo "✓ Worker Node Firewall Configured"
sudo ufw status numbered
```

---

## 📚 Additional Resources

- **Kubernetes Official Docs:** https://kubernetes.io/docs/reference/ports-and-protocols/
- **Calico Network Requirements:** https://docs.tigera.io/calico/latest/getting-started/kubernetes/requirements
- **UFW Documentation:** https://help.ubuntu.com/community/UFW

---

## ✅ Quick Checklist

**Before starting cluster setup:**

- [ ] All required ports open on master
- [ ] All required ports open on worker
- [ ] Connectivity tested with `nc` or `telnet`
- [ ] Firewall rules saved/persistent
- [ ] SSH access working (don't lock yourself out!)

**After cluster setup:**

- [ ] `kubectl get nodes` works
- [ ] Pods can communicate across nodes
- [ ] NodePort services accessible (if needed)
- [ ] No firewall-related errors in logs

---

**Last Updated:** October 25, 2025  
**Kubernetes Version:** 1.28  
**Calico Version:** 3.28.0  
**OS:** Ubuntu 24.04/22.04/20.04 LTS
