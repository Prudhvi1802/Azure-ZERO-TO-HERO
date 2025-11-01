# Quick Start - Verify Your Cluster

## ✅ Your Worker Node Joined Successfully!

Based on your output, **everything is working correctly**. The error you're seeing is **expected behavior**.

---

## ❌ Common Mistake: Running kubectl on Worker Node

You tried:
```bash
# ON WORKER NODE (WRONG!)
azureuser@worker-node:~$ kubectl get nodes
# Error: connection refused - THIS IS EXPECTED!
```

**Why the error?**
- Worker nodes **DO NOT** have kubectl configured
- Worker nodes **DO NOT** have cluster credentials (no kubeconfig)
- Worker nodes are for **running workloads only**, not managing the cluster

---

## ✅ Correct Way: Run kubectl on Master Node

### Step 1: Connect to Master Node

```bash
# From your Windows machine
ssh azureuser@<master-ip>

# Example:
ssh azureuser@172.17.0.4
```

### Step 2: Verify Cluster on Master

```bash
# ON MASTER NODE (CORRECT!)
azureuser@master-node:~$ kubectl get nodes -o wide
```

**Expected output:**
```
NAME          STATUS   ROLES           AGE   VERSION   INTERNAL-IP   EXTERNAL-IP
master-node   Ready    control-plane   10m   v1.28.x   172.17.0.4    <none>
worker-node   Ready    <none>          2m    v1.28.x   172.17.0.5    <none>
```

### Step 3: Check All Pods

```bash
# ON MASTER NODE
kubectl get pods --all-namespaces
```

**Expected output:**
```
NAMESPACE         NAME                                  READY   STATUS    RESTARTS
calico-system     calico-kube-controllers-xxx           1/1     Running   0
calico-system     calico-node-xxx                       1/1     Running   0
calico-system     calico-node-yyy                       1/1     Running   0
calico-system     calico-typha-xxx                      1/1     Running   0
kube-system       coredns-xxx                           1/1     Running   0
kube-system       coredns-yyy                           1/1     Running   0
kube-system       etcd-master-node                      1/1     Running   0
kube-system       kube-apiserver-master-node            1/1     Running   0
kube-system       kube-controller-manager-master-node   1/1     Running   0
kube-system       kube-proxy-xxx                        1/1     Running   0
kube-system       kube-proxy-yyy                        1/1     Running   0
kube-system       kube-scheduler-master-node            1/1     Running   0
tigera-operator   tigera-operator-xxx                   1/1     Running   0
```

### Step 4: Check Worker Node Details

```bash
# ON MASTER NODE
kubectl describe node worker-node
```

---

## 📊 Quick Status Check

### On Master Node Only:

```bash
# Check nodes
kubectl get nodes

# Check pods on worker
kubectl get pods --all-namespaces -o wide | grep worker-node

# Check if worker is ready
kubectl get node worker-node

# Watch nodes until Ready
kubectl get nodes -w
```

---

## 🎯 Summary - Where to Run Commands

| Task | Run On | Command |
|------|--------|---------|
| ✅ Check cluster status | **Master** | `kubectl get nodes` |
| ✅ Deploy applications | **Master** | `kubectl apply -f app.yaml` |
| ✅ View pods | **Master** | `kubectl get pods` |
| ✅ Check logs | **Master** | `kubectl logs <pod-name>` |
| ✅ Scale deployments | **Master** | `kubectl scale deployment` |
| ❌ Manage cluster | Worker | **NEVER** |
| ❌ Run kubectl | Worker | **NEVER** |
| ✅ Check kubelet logs | Worker | `journalctl -u kubelet -f` |
| ✅ Check containerd | Worker | `systemctl status containerd` |

---

## 🔍 Troubleshooting

### Node Status is "NotReady"

```bash
# ON MASTER NODE
kubectl get nodes

# If worker shows NotReady, wait 1-2 minutes for Calico to start
kubectl get pods -n calico-system

# Check node details
kubectl describe node worker-node
```

### Pods are Pending

```bash
# ON MASTER NODE
kubectl get pods --all-namespaces

# Check events
kubectl get events --sort-by='.lastTimestamp'

# Check specific pod
kubectl describe pod <pod-name> -n <namespace>
```

### Worker kubelet issues

```bash
# ON WORKER NODE (only for troubleshooting kubelet itself)
sudo journalctl -u kubelet -f

# Check containerd
sudo systemctl status containerd

# Restart kubelet if needed
sudo systemctl restart kubelet
```

---

## ✅ Your Cluster is Ready!

If you can run `kubectl get nodes` **on the master node** and see both nodes as "Ready", your cluster is working perfectly!

### Next Steps:

1. **Deploy a test application:**
   ```bash
   # ON MASTER NODE
   kubectl create deployment nginx --image=nginx --replicas=2
   kubectl expose deployment nginx --port=80 --type=NodePort
   kubectl get svc nginx
   ```

2. **Check pod placement:**
   ```bash
   # ON MASTER NODE
   kubectl get pods -o wide
   # You should see pods running on both master and worker
   ```

3. **Access your application:**
   ```bash
   # Get the NodePort
   kubectl get svc nginx
   
   # Access from browser or curl
   curl http://<any-node-ip>:<node-port>
   ```

---

## 📝 Remember

- 🎯 **Master Node**: Where you manage the cluster (kubectl commands)
- 🎯 **Worker Nodes**: Where your applications run (pods)
- ✅ **Always SSH to master** to run kubectl commands
- ❌ **Never run kubectl on workers** - they don't have cluster access

---

## 🆘 Still Having Issues?

If nodes show "NotReady" status after 5 minutes:

```bash
# ON MASTER NODE
kubectl get nodes
kubectl get pods -n calico-system
kubectl get pods -n kube-system
kubectl describe node worker-node

# ON WORKER NODE
sudo journalctl -u kubelet --since "10 minutes ago"
```

The most common issue is Calico pods not starting. Wait 2-3 minutes after joining for all pods to be Running.

---

**Your cluster setup is complete! The error you saw was expected behavior - everything is working correctly!**
