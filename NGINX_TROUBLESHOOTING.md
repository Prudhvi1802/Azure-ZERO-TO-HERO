# Nginx Deployment Troubleshooting Guide

## Common Issues When Accessing Nginx

Let's diagnose why you can't access nginx from the master node.

---

## 📋 Step 1: Check How You Deployed Nginx

### Method A: Did you create a Deployment?

```bash
# ON MASTER NODE
kubectl get deployments
kubectl get pods -o wide
```

### Method B: Did you create a Service?

```bash
# ON MASTER NODE
kubectl get services
kubectl get svc nginx -o wide
```

**IMPORTANT:** You need BOTH a deployment AND a service to access nginx!

---

## 🔍 Step 2: Identify the Problem

### Scenario 1: No Service Created (Most Common Issue)

If you only created a deployment/pod without a service:

```bash
# Check if service exists
kubectl get svc nginx

# If you see "Error: services "nginx" not found", you need to create a service!
```

**Solution:**
```bash
# Create a NodePort service
kubectl expose deployment nginx --port=80 --type=NodePort --name=nginx

# OR if you deployed a pod directly
kubectl expose pod nginx --port=80 --type=NodePort --name=nginx
```

### Scenario 2: Using ClusterIP (Default)

```bash
# Check service type
kubectl get svc nginx

# Output might show:
# NAME    TYPE        CLUSTER-IP      PORT(S)   AGE
# nginx   ClusterIP   10.96.100.100   80/TCP    5m
```

**Problem:** ClusterIP is only accessible from within the cluster, not from outside!

**Solution: Change to NodePort or LoadBalancer:**
```bash
# Delete the ClusterIP service
kubectl delete svc nginx

# Create NodePort service
kubectl expose deployment nginx --port=80 --type=NodePort
```

### Scenario 3: Using NodePort (Correct for VM Setup)

```bash
# Check service
kubectl get svc nginx

# Output should show:
# NAME    TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
# nginx   NodePort   10.96.100.100   <none>        80:30XXX/TCP   5m
```

The `30XXX` is your NodePort (usually between 30000-32767).

---

## ✅ Correct Deployment Steps

### Complete Example (Run on MASTER):

```bash
# 1. Create nginx deployment
kubectl create deployment nginx --image=nginx --replicas=2

# 2. Wait for pods to be running
kubectl get pods -o wide
# Wait until STATUS shows "Running"

# 3. Expose as NodePort service
kubectl expose deployment nginx --port=80 --type=NodePort

# 4. Get the NodePort
kubectl get svc nginx

# Output example:
# NAME    TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
# nginx   NodePort   10.96.100.100   <none>        80:30080/TCP   1m
#                                                      ^^^^^^
#                                                   This is the NodePort!
```

---

## 🌐 How to Access Nginx

### Method 1: Using NodePort (Recommended)

After creating NodePort service:

```bash
# Get the NodePort
kubectl get svc nginx -o jsonpath='{.spec.ports[0].nodePort}'

# Example output: 30080
```

**Access from Master Node:**
```bash
# Using worker IP and NodePort
curl http://172.17.0.5:30080

# Using master IP and NodePort (if pod is on master)
curl http://172.17.0.4:30080

# Using localhost if on the node where pod is running
curl http://localhost:30080
```

**Access from Windows Machine:**
```bash
# Open browser or use curl
http://<master-or-worker-public-ip>:30080
```

### Method 2: Using ClusterIP (Internal Only)

Only works from within the cluster:

```bash
# Get ClusterIP
kubectl get svc nginx

# Example: ClusterIP is 10.96.100.100

# Access from any pod in the cluster
kubectl run -it --rm debug --image=busybox --restart=Never -- wget -O- http://10.96.100.100

# Access using service DNS name
kubectl run -it --rm debug --image=busybox --restart=Never -- wget -O- http://nginx.default.svc.cluster.local
```

### Method 3: Using Port Forward (For Testing)

```bash
# Forward local port to service
kubectl port-forward svc/nginx 8080:80

# Then access on master node:
curl http://localhost:8080
```

---

## 🔧 Complete Diagnostic Commands

Run these on MASTER node to diagnose:

```bash
# 1. Check deployments
kubectl get deployments -o wide

# 2. Check pods and where they're running
kubectl get pods -o wide

# 3. Check services
kubectl get svc

# 4. Check service details
kubectl describe svc nginx

# 5. Check if nginx is actually running in the pod
kubectl get pods | grep nginx
kubectl logs <nginx-pod-name>

# 6. Check pod details
kubectl describe pod <nginx-pod-name>

# 7. Test from within the cluster
kubectl run -it --rm debug --image=busybox --restart=Never -- wget -O- http://<pod-ip>:80

# 8. Check endpoints
kubectl get endpoints nginx
```

---

## 🎯 Common Issues and Solutions

### Issue 1: "Connection refused" from master

**Symptoms:**
```bash
curl http://172.17.0.5:80
# curl: (7) Failed to connect to 172.17.0.5 port 80: Connection refused
```

**Cause:** Port 80 is not exposed. You need to use the NodePort (30000+) range.

**Solution:**
```bash
# Get the correct port
kubectl get svc nginx

# Use the NodePort (e.g., 30080)
curl http://172.17.0.5:30080
```

### Issue 2: "No route to host"

**Cause:** Firewall blocking the port or pods not ready.

**Solution:**
```bash
# Check if pods are running
kubectl get pods -o wide

# Check if service has endpoints
kubectl get endpoints nginx

# If no endpoints, pods aren't ready
kubectl describe pod <nginx-pod-name>
```

### Issue 3: Service not found

**Symptoms:**
```bash
kubectl get svc nginx
# Error from server (NotFound): services "nginx" not found
```

**Solution:**
```bash
# Create the service
kubectl expose deployment nginx --port=80 --type=NodePort
```

### Issue 4: Pod is Pending

**Symptoms:**
```bash
kubectl get pods
# NAME                     READY   STATUS    RESTARTS   AGE
# nginx-7854ff8877-abcde   0/1     Pending   0          5m
```

**Solution:**
```bash
# Check why it's pending
kubectl describe pod <nginx-pod-name>

# Common causes:
# - Insufficient resources
# - Node selector issues
# - Image pull errors

# Check node resources
kubectl top nodes
kubectl describe node worker-node
```

### Issue 5: ImagePullBackOff

**Symptoms:**
```bash
kubectl get pods
# NAME                     READY   STATUS             RESTARTS   AGE
# nginx-7854ff8877-abcde   0/1     ImagePullBackOff   0          5m
```

**Solution:**
```bash
# Check the error
kubectl describe pod <nginx-pod-name>

# Usually means:
# - No internet connectivity
# - Wrong image name
# - Private registry without credentials

# Test internet connectivity
kubectl run -it --rm test --image=busybox --restart=Never -- ping -c 3 8.8.8.8
```

---

## 📝 Working Example - Step by Step

### Complete Working Setup:

```bash
# === ON MASTER NODE ===

# 1. Create deployment
kubectl create deployment nginx --image=nginx --replicas=2
# deployment.apps/nginx created

# 2. Wait for pods (give it 1-2 minutes)
kubectl get pods -w
# Press Ctrl+C when STATUS shows Running

# 3. Check where pods are running
kubectl get pods -o wide
# NAME                     READY   STATUS    NODE
# nginx-7854ff8877-abcde   1/1     Running   worker-node
# nginx-7854ff8877-fghij   1/1     Running   master-node

# 4. Expose as NodePort
kubectl expose deployment nginx --port=80 --type=NodePort
# service/nginx exposed

# 5. Get the service details
kubectl get svc nginx
# NAME    TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
# nginx   NodePort   10.96.150.200   <none>        80:30155/TCP   10s

# 6. Note the NodePort (30155 in this example)
NODE_PORT=$(kubectl get svc nginx -o jsonpath='{.spec.ports[0].nodePort}')
echo $NODE_PORT

# 7. Test from master node
curl http://172.17.0.4:$NODE_PORT
curl http://172.17.0.5:$NODE_PORT

# 8. You should see nginx welcome page HTML
# Expected output:
# <!DOCTYPE html>
# <html>
# <head>
# <title>Welcome to nginx!</title>
# ...
```

---

## 🚀 Quick Test Commands

```bash
# === RUN THESE ON MASTER NODE ===

# Create and expose nginx in one go
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --port=80 --type=NodePort

# Wait for pods
sleep 30

# Get info
kubectl get pods -o wide
kubectl get svc nginx

# Test connectivity
NODE_PORT=$(kubectl get svc nginx -o jsonpath='{.spec.ports[0].nodePort}')
echo "Testing nginx on port $NODE_PORT"
curl -I http://localhost:$NODE_PORT
curl -I http://172.17.0.4:$NODE_PORT
curl -I http://172.17.0.5:$NODE_PORT

# If successful, you'll see HTTP/1.1 200 OK
```

---

## 📊 Network Flow Diagram

```
Browser/curl on Master (172.17.0.4)
         |
         | Access via NodePort (30XXX)
         ↓
Master Node (172.17.0.4:30XXX) ----→ kube-proxy
                                         |
         ┌──────────────────────────────┤
         ↓                               ↓
  Pod on Master                   Pod on Worker
  (10.244.0.X:80)               (10.244.1.X:80)
         ↓                               ↓
    nginx container              nginx container
```

---

## ✅ Verification Checklist

- [ ] Deployment exists: `kubectl get deployments`
- [ ] Pods are running: `kubectl get pods` (STATUS = Running)
- [ ] Service exists: `kubectl get svc nginx`
- [ ] Service type is NodePort: `kubectl get svc nginx -o wide`
- [ ] Service has endpoints: `kubectl get endpoints nginx`
- [ ] NodePort is in 30000-32767 range
- [ ] Used correct IP:Port combination
- [ ] Firewall allows NodePort traffic (if accessing from outside)

---

## 🆘 Still Not Working?

Provide these outputs for further diagnosis:

```bash
# ON MASTER NODE
kubectl get nodes -o wide
kubectl get deployments -o wide
kubectl get pods -o wide
kubectl get svc -o wide
kubectl get endpoints nginx
kubectl describe svc nginx
kubectl logs <nginx-pod-name>
curl -v http://<node-ip>:<nodeport>
```

---

**Remember:** NodePort services are accessible on **ANY** node IP in the cluster at the **same port**!
