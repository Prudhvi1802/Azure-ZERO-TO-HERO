# CI/CD Quick Reference Guide

Quick command reference for common tasks in your CI/CD pipeline.

---

## 🚀 GitLab Runner Commands

### Installation & Setup
```bash
# Navigate to runner setup directory
cd gitlab-runner-setup

# Install GitLab Runner
sudo ./gitlab-runner-install.sh

# Register runner with GitLab
sudo ./gitlab-runner-register.sh

# Check runner health
./gitlab-runner-check.sh
```

### Managing Runner
```bash
# Verify runner connection
sudo gitlab-runner verify

# List registered runners
sudo gitlab-runner list

# Restart runner
sudo systemctl restart gitlab-runner

# Check runner status
sudo systemctl status gitlab-runner

# View runner logs
sudo journalctl -u gitlab-runner -f

# Unregister runner
sudo ./gitlab-runner-unregister.sh
```

### Docker Management
```bash
# Check Docker status
sudo systemctl status docker

# Restart Docker
sudo systemctl restart docker

# Clean up Docker resources
docker system prune -a

# View Docker images
docker images

# View running containers
docker ps
```

---

## ☸️ Kubernetes Commands

### Setup
```bash
# Navigate to kubernetes setup directory
cd kubernetes-setup

# Run complete setup
./k8s-setup.sh

# Generate kubeconfig for GitLab
./generate-kubeconfig.sh
```

### Verification
```bash
# Check namespace
kubectl get namespace production

# Check ServiceAccount
kubectl get serviceaccount gitlab-deployer -n production

# Check secret
kubectl get secret gitlab-deployer-token -n production

# Check RBAC
kubectl get role gitlab-deployer-role -n production
kubectl get rolebinding gitlab-deployer-binding -n production
```

### Deployment Management
```bash
# List deployments
kubectl get deployments -n production

# Describe deployment
kubectl describe deployment my-microservice -n production

# View deployment history
kubectl rollout history deployment/my-microservice -n production

# Check rollout status
kubectl rollout status deployment/my-microservice -n production

# Rollback deployment
kubectl rollout undo deployment/my-microservice -n production

# Scale deployment
kubectl scale deployment my-microservice --replicas=3 -n production
```

### Pod Management
```bash
# List pods
kubectl get pods -n production

# Watch pods
kubectl get pods -n production -w

# Describe pod
kubectl describe pod <pod-name> -n production

# View pod logs
kubectl logs <pod-name> -n production

# Follow pod logs
kubectl logs -f <pod-name> -n production

# Execute command in pod
kubectl exec -it <pod-name> -n production -- /bin/bash
```

### Service Management
```bash
# List services
kubectl get services -n production

# Describe service
kubectl describe service my-microservice -n production

# Get service endpoints
kubectl get endpoints my-microservice -n production
```

### Debugging
```bash
# Get events
kubectl get events -n production --sort-by='.lastTimestamp'

# Check resource usage
kubectl top pods -n production
kubectl top nodes

# Port forward for testing
kubectl port-forward deployment/my-microservice 8080:8080 -n production
```

---

## 🔍 SonarQube Commands

### Docker Deployment
```bash
# Start SonarQube
cd /opt/sonarqube
sudo docker-compose up -d

# Stop SonarQube
sudo docker-compose stop

# View logs
sudo docker logs -f sonarqube

# Restart SonarQube
sudo docker-compose restart

# Remove SonarQube
sudo docker-compose down
```

### Health Check
```bash
# Check SonarQube health
curl http://localhost:9000/api/system/health

# Check SonarQube status
curl http://localhost:9000/api/system/status

# Validate token
curl -u YOUR_TOKEN: http://localhost:9000/api/authentication/validate
```

---

## 📊 Pipeline Commands

### Trigger Pipeline
```bash
# Push to trigger pipeline
git add .
git commit -m "Your commit message"
git push origin main

# Skip SonarQube analysis
git commit -m "Your message [skip-sonar]"
```

### Monitor Pipeline
```bash
# View in GitLab
# Go to: Project → CI/CD → Pipelines

# Check latest pipeline status
# Project → CI/CD → Pipelines → Latest

# View job logs
# Click on any job in the pipeline
```

---

## 🔐 Security & Secrets

### GitLab CI/CD Variables
```bash
# Access in GitLab
# Settings → CI/CD → Variables

# Add variable via GitLab UI
# Key: VARIABLE_NAME
# Value: variable_value
# Protected: Yes (for production)
# Masked: Yes (for secrets)
```

### Generate Base64 for Kubeconfig
```bash
# Encode kubeconfig
cat gitlab-ci-kubeconfig.yaml | base64 -w 0

# Decode kubeconfig (for testing)
echo "$KUBE_CONFIG" | base64 -d > /tmp/config
export KUBECONFIG=/tmp/config
kubectl cluster-info
```

### Rotate ServiceAccount Token
```bash
cd kubernetes-setup

# Delete old secret
kubectl delete secret gitlab-deployer-token -n production

# Recreate secret
kubectl apply -f k8s-serviceaccount.yaml

# Wait for creation
sleep 5

# Generate new kubeconfig
./generate-kubeconfig.sh

# Update GitLab variable with new base64 output
```

---

## 🐛 Troubleshooting

### Runner Issues
```bash
# Runner not picking up jobs
sudo gitlab-runner verify
sudo systemctl restart gitlab-runner
sudo journalctl -u gitlab-runner -n 50

# Docker permission issues
sudo usermod -aG docker gitlab-runner
sudo systemctl restart gitlab-runner
newgrp docker

# Check runner logs for errors
sudo journalctl -u gitlab-runner --since "1 hour ago"
```

### Kubernetes Issues
```bash
# Cannot connect to cluster
kubectl cluster-info
kubectl get nodes

# Permission denied
kubectl auth can-i list pods --as=system:serviceaccount:production:gitlab-deployer -n production

# Deployment not updating
kubectl describe deployment my-microservice -n production
kubectl get events -n production

# Pods not starting
kubectl describe pod <pod-name> -n production
kubectl logs <pod-name> -n production
```

### Pipeline Issues
```bash
# Job stuck in pending
# Check: Runner is online in GitLab
# Check: Job tags match runner tags
# Check: Runner has available executors

# Build failures
# Check: Maven dependencies
# Check: Test failures in job logs
# Check: Docker daemon is running

# Deployment failures
# Check: kubeconfig is valid
# Check: Deployment exists in namespace
# Check: Image exists in registry
```

---

## 📈 Monitoring Commands

### Resource Usage
```bash
# Kubernetes resources
kubectl top nodes
kubectl top pods -n production

# Docker resources
docker stats
docker system df

# System resources
htop
df -h
free -h
```

### Logs
```bash
# GitLab Runner logs
sudo journalctl -u gitlab-runner -f

# Docker logs
sudo journalctl -u docker -f

# Application logs
kubectl logs -f deployment/my-microservice -n production

# SonarQube logs
sudo docker logs -f sonarqube
```

---

## 🧹 Cleanup Commands

### Clean Docker Resources
```bash
# Remove unused images
docker image prune -a

# Remove stopped containers
docker container prune

# Remove unused volumes
docker volume prune

# Remove everything unused
docker system prune -a --volumes
```

### Clean Kubernetes Resources
```bash
# Delete failed pods
kubectl delete pods --field-selector status.phase=Failed -n production

# Delete evicted pods
kubectl get pods -n production | grep Evicted | awk '{print $1}' | xargs kubectl delete pod -n production

# Clean up old replicasets
kubectl delete replicaset -n production --field-selector 'status.replicas=0'
```

---

## 📋 Common Pipeline Variables

Add these to GitLab → Settings → CI/CD → Variables:

```
KUBE_CONFIG              = <base64-encoded-kubeconfig>  [Protected, Masked]
SONAR_HOST_URL          = http://your-ip:9000
SONAR_TOKEN             = <your-sonarqube-token>        [Protected, Masked]
SONAR_PROJECT_KEY       = your-project-key
DEPLOYMENT_NAME         = my-microservice
CONTAINER_NAME          = app
KUBERNETES_NAMESPACE    = production
```

---

## 🔗 Quick Links

### GitLab
- **Pipelines**: Project → CI/CD → Pipelines
- **Variables**: Project → Settings → CI/CD → Variables
- **Runners**: Project → Settings → CI/CD → Runners
- **Container Registry**: Project → Packages & Registries → Container Registry

### Kubernetes Dashboard (if installed)
```bash
# Get token for dashboard
kubectl -n kubernetes-dashboard create token admin-user

# Access dashboard
kubectl proxy
# Open: http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/
```

### SonarQube
- **URL**: http://your-sonarqube-ip:9000
- **Projects**: My Account → Projects
- **Tokens**: My Account → Security → Tokens
- **Quality Gates**: Quality Gates → Show → Your Project

---

## 💡 Useful Aliases

Add to `~/.bashrc` or `~/.bash_aliases`:

```bash
# Kubernetes
alias k='kubectl'
alias kgp='kubectl get pods -n production'
alias kgd='kubectl get deployments -n production'
alias kgs='kubectl get services -n production'
alias kdp='kubectl describe pod -n production'
alias klf='kubectl logs -f -n production'

# GitLab Runner
alias gr-status='sudo systemctl status gitlab-runner'
alias gr-restart='sudo systemctl restart gitlab-runner'
alias gr-logs='sudo journalctl -u gitlab-runner -f'

# Docker
alias dps='docker ps'
alias dimg='docker images'
alias dprune='docker system prune -a'
```

Reload aliases:
```bash
source ~/.bashrc
```

---

## 📞 Getting Help

### Documentation
- [CICD-SETUP-GUIDE.md](CICD-SETUP-GUIDE.md) - Complete setup guide
- [README-CICD.md](README-CICD.md) - Project overview
- [gitlab-runner-setup/README.md](gitlab-runner-setup/README.md) - Runner docs
- [kubernetes-setup/README.md](kubernetes-setup/README.md) - K8s docs

### Health Checks
```bash
# Run all health checks
./gitlab-runner-check.sh
kubectl get all -n production
curl http://your-sonarqube-ip:9000/api/system/health
```

---

**Keep this guide handy for daily operations!** 📖
