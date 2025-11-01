# Kubernetes Setup for GitLab CI/CD

Configuration files and scripts to set up Kubernetes resources for GitLab CI/CD deployments.

## 📂 Files Overview

| File | Purpose |
|------|---------|
| `k8s-namespace.yaml` | Creates the `production` namespace |
| `k8s-serviceaccount.yaml` | ServiceAccount for CI/CD with token secret |
| `k8s-rbac.yaml` | Role and RoleBinding with deployment permissions |
| `k8s-setup.sh` | Automated setup script for all resources |
| `generate-kubeconfig.sh` | Generates kubeconfig for GitLab CI/CD |

## 🚀 Quick Start

### Prerequisites

- kubectl installed and configured
- Access to Kubernetes cluster
- Appropriate permissions to create namespaces and RBAC resources

### Step 1: Apply All Resources

```bash
# Make scripts executable
chmod +x *.sh

# Run the setup script
./k8s-setup.sh
```

This will:
1. Create `production` namespace
2. Create `gitlab-deployer` ServiceAccount
3. Create Role with deployment permissions
4. Create RoleBinding

### Step 2: Generate Kubeconfig

```bash
./generate-kubeconfig.sh
```

This will:
1. Extract ServiceAccount token
2. Generate kubeconfig file
3. Output base64 encoded kubeconfig for GitLab

**Save the base64 output** - you'll need it for GitLab CI/CD variables.

## 📝 Manual Setup (Alternative)

If you prefer to apply resources manually:

```bash
# Step 1: Create namespace
kubectl apply -f k8s-namespace.yaml

# Step 2: Create ServiceAccount and Secret
kubectl apply -f k8s-serviceaccount.yaml

# Step 3: Create RBAC resources
kubectl apply -f k8s-rbac.yaml

# Wait for secret to be created
sleep 5

# Step 4: Generate kubeconfig
./generate-kubeconfig.sh
```

## 🔍 Verification

### Check Namespace

```bash
kubectl get namespace production
```

### Check ServiceAccount

```bash
kubectl get serviceaccount gitlab-deployer -n production
```

### Check Secret

```bash
kubectl get secret gitlab-deployer-token -n production
```

### Check RBAC

```bash
# List role
kubectl get role gitlab-deployer-role -n production

# List rolebinding
kubectl get rolebinding gitlab-deployer-binding -n production

# Describe role to see permissions
kubectl describe role gitlab-deployer-role -n production
```

### Test ServiceAccount Permissions

```bash
# Check if ServiceAccount can list pods
kubectl auth can-i list pods \
  --as=system:serviceaccount:production:gitlab-deployer \
  -n production

# Check if ServiceAccount can update deployments
kubectl auth can-i update deployments \
  --as=system:serviceaccount:production:gitlab-deployer \
  -n production
```

## 🔐 Security Configuration

### Permissions Granted

The `gitlab-deployer` ServiceAccount has permissions to:

**Deployments:**
- get, list, watch, create, update, patch, delete

**ReplicaSets:**
- get, list, watch

**Pods:**
- get, list, watch

**Pods/logs:**
- get, list

**Services:**
- get, list, watch, create, update, patch

**ConfigMaps:**
- get, list, watch, create, update, patch

**Secrets:**
- get, list, watch (read-only)

### Least Privilege Principle

The permissions are scoped to:
- **Namespace**: `production` only
- **Resource Types**: Only deployment-related resources
- **Verbs**: Only necessary actions

## 📋 GitLab CI/CD Integration

### Step 1: Add Kubeconfig to GitLab

1. Go to your GitLab project
2. Navigate to **Settings → CI/CD → Variables**
3. Click **Add Variable**
4. Configure:
   - **Key**: `KUBE_CONFIG`
   - **Value**: Paste the base64 encoded kubeconfig
   - **Type**: Variable
   - **Protect variable**: ✅ Enabled
   - **Mask variable**: ✅ Enabled
   - **Expand variable reference**: ❌ Disabled

### Step 2: Use in Pipeline

In your `.gitlab-ci.yml`:

```yaml
deploy:
  image: bitnami/kubectl:latest
  before_script:
    - mkdir -p ~/.kube
    - echo "$KUBE_CONFIG" | base64 -d > ~/.kube/config
  script:
    - kubectl get pods -n production
    - kubectl set image deployment/my-app app=$CI_REGISTRY_IMAGE:$CI_COMMIT_SHA -n production
  only:
    - main
```

## 🔄 Updating Resources

### Modify Permissions

Edit `k8s-rbac.yaml` and apply changes:

```bash
# Edit the file
nano k8s-rbac.yaml

# Apply changes
kubectl apply -f k8s-rbac.yaml

# Verify changes
kubectl describe role gitlab-deployer-role -n production
```

### Rotate ServiceAccount Token

```bash
# Delete the secret
kubectl delete secret gitlab-deployer-token -n production

# Recreate it
kubectl apply -f k8s-serviceaccount.yaml

# Wait for new secret
sleep 5

# Generate new kubeconfig
./generate-kubeconfig.sh

# Update GitLab CI/CD variable with new base64 kubeconfig
```

## 🗑️ Cleanup

### Remove All Resources

```bash
# Delete RBAC
kubectl delete -f k8s-rbac.yaml

# Delete ServiceAccount
kubectl delete -f k8s-serviceaccount.yaml

# Delete namespace (this will delete everything in it!)
kubectl delete -f k8s-namespace.yaml
```

### Remove Specific Resources

```bash
# Remove only RBAC
kubectl delete rolebinding gitlab-deployer-binding -n production
kubectl delete role gitlab-deployer-role -n production

# Remove only ServiceAccount
kubectl delete secret gitlab-deployer-token -n production
kubectl delete serviceaccount gitlab-deployer -n production
```

## 🔧 Troubleshooting

### Secret Not Created

**Problem:** ServiceAccount token secret not automatically created

**Solution:**
```bash
# Manually create the secret
kubectl apply -f k8s-serviceaccount.yaml

# Check if secret exists
kubectl get secret gitlab-deployer-token -n production

# If still not created, check Kubernetes version
kubectl version --short
# Note: Kubernetes 1.24+ requires explicit secret creation
```

### Permission Denied Errors

**Problem:** Pipeline fails with "forbidden" errors

**Solutions:**

1. **Check ServiceAccount exists:**
```bash
kubectl get sa gitlab-deployer -n production
```

2. **Verify RBAC binding:**
```bash
kubectl get rolebinding gitlab-deployer-binding -n production -o yaml
```

3. **Test permissions:**
```bash
kubectl auth can-i <verb> <resource> \
  --as=system:serviceaccount:production:gitlab-deployer \
  -n production
```

4. **Check kubeconfig:**
```bash
echo "$KUBE_CONFIG" | base64 -d > /tmp/test-config
export KUBECONFIG=/tmp/test-config
kubectl cluster-info
```

### Cannot Connect to Cluster

**Problem:** kubectl commands fail in pipeline

**Solutions:**

1. **Verify cluster endpoint in kubeconfig:**
```bash
./generate-kubeconfig.sh
# Check the 'server:' field in output
```

2. **Check network connectivity from GitLab Runner:**
```bash
# On runner VM
curl -k https://your-k8s-api-server:6443
```

3. **Verify CA certificate:**
```bash
# Regenerate kubeconfig
./generate-kubeconfig.sh
```

## 📚 Additional Resources

- [Kubernetes RBAC Documentation](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [ServiceAccounts Documentation](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/)
- [GitLab Kubernetes Integration](https://docs.gitlab.com/ee/user/clusters/)

## 🔗 Next Steps

After completing this setup:

1. ✅ **Configure GitLab CI/CD Variables** - Add KUBE_CONFIG to GitLab
2. ✅ **Create Deployment Manifests** - Define your application deployment
3. ✅ **Update Pipeline Configuration** - Add deployment stage to .gitlab-ci.yml
4. ✅ **Test Deployment** - Run a test pipeline

---

**Ready to deploy!** Your Kubernetes cluster is now configured for GitLab CI/CD.
