# Complete CI/CD Setup Guide
## GitLab to On-Premises Kubernetes Deployment

This guide provides step-by-step instructions for setting up a complete CI/CD pipeline from GitLab.com to your on-premises Kubernetes cluster for Java microservices.

---

## 📋 Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Prerequisites](#prerequisites)
3. [Phase 1: GitLab Runner Setup](#phase-1-gitlab-runner-setup)
4. [Phase 2: SonarQube Setup](#phase-2-sonarqube-setup)
5. [Phase 3: Kubernetes Configuration](#phase-3-kubernetes-configuration)
6. [Phase 4: GitLab CI/CD Pipeline](#phase-4-gitlab-cicd-pipeline)
7. [Phase 5: Testing & Validation](#phase-5-testing--validation)
8. [Troubleshooting](#troubleshooting)

---

## 🏗️ Architecture Overview

```
┌─────────────────┐
│   GitLab.com    │
│  (Source Code   │
│   & Registry)   │
└────────┬────────┘
         │
         │ HTTPS (443)
         │
┌────────▼────────────────────────────────┐
│     Your Data Center Network            │
│                                          │
│  ┌──────────────┐    ┌──────────────┐  │
│  │ GitLab Runner│────│  SonarQube   │  │
│  │      VM      │    │  (Docker)    │  │
│  └──────┬───────┘    └──────────────┘  │
│         │                                │
│         │                                │
│  ┌──────▼───────────────────────────┐  │
│  │   Kubernetes Cluster             │  │
│  │   ┌──────────┐  ┌──────────┐    │  │
│  │   │  Master  │  │  Workers │    │  │
│  │   └──────────┘  └──────────┘    │  │
│  └──────────────────────────────────┘  │
└──────────────────────────────────────────┘
```

### Pipeline Flow

```
1. Code Push → GitLab
2. GitLab Runner (On-Premise) pulls code
3. Maven Build → Compile & Package
4. Unit Tests → Test Results
5. SonarQube → Code Quality Analysis
6. Docker Build → Container Image
7. Trivy Scan → Security Vulnerabilities
8. Push to GitLab Registry
9. Deploy to Kubernetes → Rolling Update
```

---

## ✅ Prerequisites

### System Requirements

1. **GitLab Runner VM**
   - OS: Ubuntu 20.04+ or Debian 11+
   - CPU: 2+ cores
   - RAM: 4GB minimum, 8GB recommended
   - Disk: 50GB minimum
   - Network: Outbound HTTPS (443) to GitLab.com

2. **Kubernetes Cluster**
   - Kubernetes 1.20+
   - kubectl access configured
   - Minimum 1 namespace available

3. **SonarQube (Optional but Recommended)**
   - Docker installed
   - 2GB RAM dedicated
   - 10GB disk space

### Access Requirements

- [ ] Root/sudo access to GitLab Runner VM
- [ ] kubectl access to Kubernetes cluster
- [ ] GitLab.com project with maintainer permissions
- [ ] Ability to create GitLab CI/CD variables

---

## 🚀 Phase 1: GitLab Runner Setup

### Step 1.1: Prepare Your VM

```bash
# SSH into your VM
ssh user@your-runner-vm-ip

# Update system
sudo apt-get update
sudo apt-get upgrade -y
```

### Step 1.2: Install GitLab Runner

```bash
# Navigate to the gitlab-runner-setup directory
cd ~/gitlab-runner-setup

# Make scripts executable
chmod +x *.sh

# Run installation script
sudo ./gitlab-runner-install.sh
```

**Expected Duration:** 5-10 minutes

**Verification:**
```bash
# Check GitLab Runner
gitlab-runner --version

# Check Docker
docker --version

# Check services
sudo systemctl status gitlab-runner
sudo systemctl status docker
```

### Step 1.3: Get Registration Token

1. Go to your project on GitLab.com
2. Navigate to **Settings → CI/CD**
3. Expand **Runners** section
4. Click **"New project runner"**
5. Copy the registration token (starts with `glrt-`)

### Step 1.4: Register the Runner

```bash
sudo ./gitlab-runner-register.sh
```

**Interactive Prompts:**
- GitLab URL: `https://gitlab.com` (press Enter)
- Registration token: Paste your token
- Description: `on-premise-runner` (or custom)
- Tags: `on-premise-runner,docker` (recommended)
- Executor: Select `1` for docker

### Step 1.5: Verify Installation

```bash
./gitlab-runner-check.sh
```

**Expected Output:**
```
✅ GitLab Runner is installed
✅ GitLab Runner service is running
✅ Docker service is running
✅ gitlab-runner user is in docker group
```

---

## 🔍 Phase 2: SonarQube Setup

### Option A: Docker Deployment (Recommended)

```bash
# Create directory for SonarQube
sudo mkdir -p /opt/sonarqube/{data,extensions,logs,conf}
sudo chown -R 1000:1000 /opt/sonarqube

# Create docker-compose.yml
cd /opt/sonarqube

# Copy the docker-compose configuration
# (Refer to sonarqube-setup/docker-compose.yml)

# Start SonarQube
sudo docker-compose up -d

# Wait for startup (2-3 minutes)
sudo docker logs -f sonarqube
```

### Step 2.1: Access SonarQube

1. Open browser: `http://your-sonarqube-vm-ip:9000`
2. Login with default credentials:
   - Username: `admin`
   - Password: `admin`
3. **Change password immediately**

### Step 2.2: Create Project

1. Click **"Create Project"** → **"Manually"**
2. Project key: `your-microservice-key`
3. Display name: `Your Microservice`
4. Click **"Set Up"**

### Step 2.3: Generate Token

1. Go to **My Account → Security → Generate Token**
2. Name: `gitlab-ci`
3. Type: **Project Analysis Token**
4. Click **Generate**
5. **Copy and save the token securely**

---

## ☸️ Phase 3: Kubernetes Configuration

### Step 3.1: Setup Kubernetes Resources

```bash
# Navigate to kubernetes-setup directory
cd ~/kubernetes-setup

# Make script executable
chmod +x *.sh

# Run the setup script
./k8s-setup.sh
```

This script will:
- Create `production` namespace
- Create `gitlab-deployer` ServiceAccount
- Configure RBAC permissions

**Expected Output:**
```
✅ Namespace created
✅ ServiceAccount created
✅ RBAC resources created
```

### Step 3.2: Generate Kubeconfig

```bash
# Generate kubeconfig for GitLab
./generate-kubeconfig.sh
```

This will output a **base64 encoded kubeconfig**. Copy this entire string.

**Example Output:**
```
Base64 encoded kubeconfig (for GitLab CI/CD variable):
================================================================
YXBpVmVyc2lvbjogdjEKa2luZDogQ29uZmlnCmNsdXN0ZXJzOgotIGNsdXN0ZXI6...
================================================================
```

---

## 🔧 Phase 4: GitLab CI/CD Pipeline

### Step 4.1: Configure GitLab CI/CD Variables

1. Go to your GitLab project
2. Navigate to **Settings → CI/CD → Variables**
3. Add the following variables:

| Variable Name | Value | Type | Protected | Masked |
|---------------|-------|------|-----------|--------|
| `KUBE_CONFIG` | [base64 kubeconfig from Step 3.2] | Variable | ✅ Yes | ✅ Yes |
| `SONAR_HOST_URL` | `http://your-sonarqube-ip:9000` | Variable | ❌ No | ❌ No |
| `SONAR_TOKEN` | [Token from Step 2.3] | Variable | ✅ Yes | ✅ Yes |
| `SONAR_PROJECT_KEY` | `your-microservice-key` | Variable | ❌ No | ❌ No |
| `DEPLOYMENT_NAME` | `my-microservice` | Variable | ❌ No | ❌ No |
| `CONTAINER_NAME` | `app` | Variable | ❌ No | ❌ No |

### Step 4.2: Add Pipeline Configuration

```bash
# Copy .gitlab-ci.yml to your project root
cp cicd-pipeline/.gitlab-ci.yml /path/to/your/project/.gitlab-ci.yml

# Commit and push
cd /path/to/your/project
git add .gitlab-ci.yml
git commit -m "Add CI/CD pipeline configuration"
git push origin main
```

### Step 4.3: Create Dockerfile

Create a `Dockerfile` in your project root:

```dockerfile
FROM openjdk:17-jdk-slim
WORKDIR /app
COPY target/*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
```

### Step 4.4: Create Kubernetes Deployment

Create `k8s-deployment.yaml` in your project:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-microservice
  namespace: production
spec:
  replicas: 2
  selector:
    matchLabels:
      app: my-microservice
  template:
    metadata:
      labels:
        app: my-microservice
    spec:
      containers:
      - name: app
        image: registry.gitlab.com/your-username/your-project:latest
        ports:
        - containerPort: 8080
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
---
apiVersion: v1
kind: Service
metadata:
  name: my-microservice
  namespace: production
spec:
  selector:
    app: my-microservice
  ports:
  - protocol: TCP
    port: 80
    targetPort: 8080
  type: LoadBalancer
```

Deploy it manually first:
```bash
kubectl apply -f k8s-deployment.yaml
```

---

## ✅ Phase 5: Testing & Validation

### Step 5.1: Test Pipeline

1. Make a change to your code
2. Commit and push to `main` branch
3. Go to **CI/CD → Pipelines** in GitLab
4. Watch the pipeline execute

**Expected Stages:**
1. ✅ Build (Maven compile & package)
2. ✅ Test (Unit tests)
3. ✅ Code Quality (SonarQube)
4. ✅ Docker Build (Container image)
5. ✅ Security Scan (Trivy)
6. ⏸️ Deploy (Manual trigger)

### Step 5.2: Manual Deployment

1. Click on the **Deploy** stage
2. Click **"play"** button for `deploy-production`
3. Monitor deployment:

```bash
# Watch pods
kubectl get pods -n production -w

# Check deployment status
kubectl rollout status deployment/my-microservice -n production

# View logs
kubectl logs -f deployment/my-microservice -n production
```

### Step 5.3: Verify Application

```bash
# Get service URL
kubectl get svc my-microservice -n production

# Test endpoint
curl http://<service-external-ip>
```

---

## 🔧 Troubleshooting

### Runner Issues

**Problem:** Runner not picking up jobs

**Solutions:**
```bash
# Check runner status
sudo gitlab-runner verify

# Restart runner
sudo systemctl restart gitlab-runner

# Check logs
sudo journalctl -u gitlab-runner -f
```

### Docker Permission Issues

**Problem:** Permission denied while trying to connect to Docker daemon

**Solution:**
```bash
sudo usermod -aG docker gitlab-runner
sudo systemctl restart gitlab-runner
```

### Kubernetes Connection Issues

**Problem:** kubectl cannot connect to cluster

**Solutions:**
```bash
# Verify kubeconfig
echo $KUBE_CONFIG | base64 -d > /tmp/config
export KUBECONFIG=/tmp/config
kubectl cluster-info

# Check ServiceAccount permissions
kubectl auth can-i list pods --as=system:serviceaccount:production:gitlab-deployer -n production
```

### SonarQube Issues

**Problem:** SonarQube analysis failing

**Solutions:**
```bash
# Check SonarQube is accessible
curl http://your-sonarqube-ip:9000/api/system/health

# Verify token
curl -u YOUR_TOKEN: http://your-sonarqube-ip:9000/api/authentication/validate
```

### Pipeline Job Stuck

**Problem:** Jobs stuck in pending state

**Solutions:**
1. Check runner is online in GitLab
2. Verify job tags match runner tags
3. Check runner has available executors:
```bash
sudo gitlab-runner list
```

---

## 📊 Monitoring & Maintenance

### Monitor Pipeline Performance

```bash
# GitLab → CI/CD → Pipelines
# Check average pipeline duration
# Identify slow stages
```

### Regular Maintenance Tasks

**Weekly:**
- Review failed pipelines
- Check SonarQube quality gates
- Review Trivy security reports

**Monthly:**
- Update GitLab Runner: `sudo apt-get update && sudo apt-get upgrade gitlab-runner`
- Clean up old Docker images: `docker system prune -a`
- Review and rotate service account tokens

**Quarterly:**
- Review and update pipeline configuration
- Security audit of CI/CD permissions
- Performance optimization review

---

## 🔐 Security Best Practices

1. **Protected Variables**: Always mark sensitive variables as protected and masked
2. **Branch Protection**: Configure protected branches in GitLab
3. **Token Rotation**: Rotate ServiceAccount tokens every 90 days
4. **Least Privilege**: Only grant necessary permissions to ServiceAccounts
5. **Network Segmentation**: Isolate CI/CD infrastructure
6. **Audit Logs**: Regularly review GitLab and Kubernetes audit logs
7. **Secrets Management**: Never commit secrets to repository

---

## 📚 Additional Resources

- [GitLab CI/CD Documentation](https://docs.gitlab.com/ee/ci/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [SonarQube Documentation](https://docs.sonarqube.org/)
- [Trivy Documentation](https://aquasecurity.github.io/trivy/)

---

## ✅ Checklist

- [ ] GitLab Runner installed and registered
- [ ] SonarQube deployed and configured
- [ ] Kubernetes namespace and RBAC created
- [ ] Kubeconfig generated and added to GitLab variables
- [ ] .gitlab-ci.yml added to project
- [ ] Dockerfile created
- [ ] Kubernetes deployment manifest created
- [ ] Pipeline tested successfully
- [ ] Application deployed and verified
- [ ] Monitoring and maintenance plan in place

---

**Setup Complete!** 🎉

Your CI/CD pipeline is now ready to automatically build, test, scan, and deploy your Java microservices to your on-premises Kubernetes cluster!
