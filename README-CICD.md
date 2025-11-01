# GitLab CI/CD Pipeline - On-Premises Kubernetes Deployment

Complete automation scripts and configurations for deploying Java microservices from GitLab.com to your on-premises Kubernetes cluster.

## 🎯 Overview

This project provides a production-ready CI/CD pipeline that:

✅ **Builds** Java applications with Maven  
✅ **Tests** with automated unit testing  
✅ **Analyzes** code quality with SonarQube  
✅ **Scans** for security vulnerabilities with Trivy  
✅ **Deploys** to Kubernetes with rolling updates  
✅ **Supports** rollback capabilities  

## 📦 What's Included

### 1. GitLab Runner Setup (`gitlab-runner-setup/`)
Complete scripts to install and configure GitLab Runner on your VM:
- Automated installation script
- Runner registration script
- Health check utilities
- Comprehensive documentation

### 2. Kubernetes Configuration (`kubernetes-setup/`)
RBAC and ServiceAccount setup for secure deployments:
- Namespace configuration
- ServiceAccount with limited permissions
- Kubeconfig generation
- Automated setup scripts

### 3. CI/CD Pipeline (`cicd-pipeline/`)
Production-ready GitLab CI/CD pipeline:
- Multi-stage pipeline configuration
- Maven build and test
- SonarQube integration
- Trivy security scanning
- Kubernetes deployment

### 4. Documentation
- **CICD-SETUP-GUIDE.md** - Complete step-by-step setup guide
- **README files** - Documentation for each component

## 🚀 Quick Start

### Prerequisites

- [ ] Ubuntu/Debian VM in your data center (GitLab Runner)
- [ ] Kubernetes cluster with kubectl access
- [ ] GitLab.com account with project
- [ ] Docker installed (will be automated)

### Installation Steps

**1. Clone this repository or copy files to your environment**

**2. Set up GitLab Runner** (5-10 minutes)
```bash
cd gitlab-runner-setup
chmod +x *.sh
sudo ./gitlab-runner-install.sh
sudo ./gitlab-runner-register.sh
```

**3. Configure Kubernetes** (5 minutes)
```bash
cd ../kubernetes-setup
chmod +x *.sh
./k8s-setup.sh
./generate-kubeconfig.sh
# Save the base64 output for GitLab
```

**4. Configure GitLab CI/CD Variables**
- Go to GitLab project → Settings → CI/CD → Variables
- Add required variables (see CICD-SETUP-GUIDE.md)

**5. Add Pipeline to Your Project**
```bash
cp cicd-pipeline/.gitlab-ci.yml /path/to/your/project/
cd /path/to/your/project
git add .gitlab-ci.yml
git commit -m "Add CI/CD pipeline"
git push origin main
```

## 📊 Pipeline Architecture

```
┌─────────────────────────────────────────────────────┐
│                  GitLab.com                         │
│  ┌──────────┐  ┌──────────┐  ┌──────────────────┐ │
│  │  Repo    │  │ Pipeline │  │ Container Registry│ │
│  └──────────┘  └──────────┘  └──────────────────┘ │
└────────────────────┬────────────────────────────────┘
                     │ HTTPS (443)
                     ▼
        ┌────────────────────────────┐
        │   On-Premises Runner VM    │
        │  ┌──────────────────────┐  │
        │  │  GitLab Runner       │  │
        │  │  + Docker            │  │
        │  └──────────────────────┘  │
        └────────────┬───────────────┘
                     │
        ┌────────────┼───────────────┐
        │            │               │
        ▼            ▼               ▼
   ┌────────┐  ┌──────────┐  ┌──────────┐
   │SonarQube│  │  Trivy   │  │   K8s    │
   │(Docker) │  │  Scan    │  │ Cluster  │
   └─────────┘  └──────────┘  └──────────┘
```

## 🔄 Pipeline Stages

| Stage | Description | Duration |
|-------|-------------|----------|
| 🔨 **Build** | Maven compile & package | 2-3 min |
| 🧪 **Test** | Unit tests execution | 1-2 min |
| 📊 **Code Quality** | SonarQube analysis | 2-3 min |
| 🐳 **Docker Build** | Container image creation | 1-2 min |
| 🔍 **Security Scan** | Trivy vulnerability scan | 1-2 min |
| 🚀 **Deploy** | Kubernetes deployment | 1-2 min |

**Total Pipeline Duration:** ~8-12 minutes

## 📋 GitLab CI/CD Variables Required

| Variable | Description | Protected | Masked |
|----------|-------------|-----------|--------|
| `KUBE_CONFIG` | Base64 encoded kubeconfig | ✅ | ✅ |
| `SONAR_HOST_URL` | SonarQube server URL | ❌ | ❌ |
| `SONAR_TOKEN` | SonarQube auth token | ✅ | ✅ |
| `SONAR_PROJECT_KEY` | SonarQube project key | ❌ | ❌ |
| `DEPLOYMENT_NAME` | K8s deployment name | ❌ | ❌ |
| `CONTAINER_NAME` | Container name in pod | ❌ | ❌ |

## 🎯 Pipeline Features

### Automatic Features
- ✅ Maven dependency caching
- ✅ Test result reporting
- ✅ Code coverage analysis
- ✅ Quality gate enforcement
- ✅ Security vulnerability scanning
- ✅ Automatic image tagging
- ✅ Rolling updates

### Manual Features (For Safety)
- 🔘 Production deployment
- 🔘 Deployment rollback
- 🔘 Environment stop/cleanup

## 📂 Directory Structure

```
.
├── gitlab-runner-setup/
│   ├── gitlab-runner-install.sh
│   ├── gitlab-runner-register.sh
│   ├── gitlab-runner-unregister.sh
│   ├── gitlab-runner-check.sh
│   └── README.md
│
├── kubernetes-setup/
│   ├── k8s-namespace.yaml
│   ├── k8s-serviceaccount.yaml
│   ├── k8s-rbac.yaml
│   ├── k8s-setup.sh
│   ├── generate-kubeconfig.sh
│   └── README.md
│
├── cicd-pipeline/
│   └── .gitlab-ci.yml
│
├── CICD-SETUP-GUIDE.md
└── README-CICD.md (this file)
```

## 🔧 Customization

### Adjust Pipeline for Your Project

**1. Update variables in `.gitlab-ci.yml`:**
```yaml
variables:
  DEPLOYMENT_NAME: "your-app-name"
  CONTAINER_NAME: "your-container-name"
  KUBERNETES_NAMESPACE: "production"
```

**2. Modify deployment command if needed:**
```yaml
script:
  - kubectl set image deployment/$DEPLOYMENT_NAME \
    $CONTAINER_NAME=$DOCKER_IMAGE \
    -n $KUBERNETES_NAMESPACE
```

**3. Add environment-specific stages:**
```yaml
deploy-staging:
  extends: .deploy
  variables:
    KUBERNETES_NAMESPACE: "staging"
  only:
    - develop
```

## 🔐 Security Best Practices

### ✅ Implemented Security Measures

1. **Least Privilege Access**
   - ServiceAccount limited to specific namespace
   - Only necessary RBAC permissions granted

2. **Secret Management**
   - All secrets stored in GitLab CI/CD variables
   - Variables marked as protected and masked
   - No secrets in code repository

3. **Security Scanning**
   - Trivy scans all container images
   - SonarQube analyzes code quality
   - Pipeline fails on critical issues

4. **Network Security**
   - Runner in private network
   - No inbound connections required
   - Only outbound HTTPS to GitLab.com

### 🔒 Additional Recommendations

- [ ] Enable branch protection in GitLab
- [ ] Use signed commits
- [ ] Implement image signing
- [ ] Set up vulnerability alerts
- [ ] Regular security audits
- [ ] Token rotation schedule (90 days)

## 📊 Monitoring & Maintenance

### Daily
- ✅ Monitor pipeline executions
- ✅ Review failed jobs

### Weekly
- ✅ Check SonarQube quality gates
- ✅ Review Trivy security reports
- ✅ Monitor deployment success rate

### Monthly
- ✅ Update GitLab Runner
- ✅ Clean Docker images
- ✅ Review and optimize pipeline

### Quarterly
- ✅ Rotate ServiceAccount tokens
- ✅ Review RBAC permissions
- ✅ Security audit
- ✅ Performance optimization

## 🐛 Common Issues & Solutions

### Issue: Runner not picking up jobs
```bash
sudo gitlab-runner verify
sudo systemctl restart gitlab-runner
```

### Issue: Docker permission denied
```bash
sudo usermod -aG docker gitlab-runner
sudo systemctl restart gitlab-runner
```

### Issue: Kubernetes connection failed
```bash
# Regenerate kubeconfig
cd kubernetes-setup
./generate-kubeconfig.sh
# Update GitLab variable with new base64 output
```

### Issue: SonarQube analysis failed
```bash
# Check SonarQube is running
curl http://your-sonarqube-ip:9000/api/system/health
# Verify token in GitLab variables
```

## 📚 Documentation

- **[CICD-SETUP-GUIDE.md](CICD-SETUP-GUIDE.md)** - Complete setup guide with detailed instructions
- **[gitlab-runner-setup/README.md](gitlab-runner-setup/README.md)** - GitLab Runner documentation
- **[kubernetes-setup/README.md](kubernetes-setup/README.md)** - Kubernetes configuration guide

## 🔗 External Resources

- [GitLab CI/CD Docs](https://docs.gitlab.com/ee/ci/)
- [Kubernetes Docs](https://kubernetes.io/docs/)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [SonarQube Docs](https://docs.sonarqube.org/)
- [Trivy Docs](https://aquasecurity.github.io/trivy/)

## 💡 Tips & Tricks

### Speed Up Pipeline

1. **Use caching effectively**
   ```yaml
   cache:
     key: ${CI_COMMIT_REF_SLUG}
     paths:
       - .m2/repository/
   ```

2. **Parallel job execution**
   ```yaml
   test:
     parallel: 3
   ```

3. **Skip unnecessary stages**
   ```bash
   git commit -m "docs: update README [skip-sonar]"
   ```

### Better Debugging

1. **Enable debug mode**
   ```yaml
   variables:
     CI_DEBUG_TRACE: "true"
   ```

2. **Access job artifacts**
   - Download from GitLab UI
   - Review logs in pipeline view

3. **Test locally with Docker**
   ```bash
   docker run -it maven:3.8-openjdk-17 bash
   # Test your build commands
   ```

## 🤝 Contributing

To improve this CI/CD setup:

1. Test changes in a feature branch
2. Update documentation
3. Verify all scripts work
4. Share improvements

## 📝 License

This project is provided as-is for educational and production use.

## 🙋 Support

For issues:
1. Check [Troubleshooting](#-common-issues--solutions)
2. Review [CICD-SETUP-GUIDE.md](CICD-SETUP-GUIDE.md)
3. Check component READMEs
4. Verify all prerequisites

---

**Ready to automate your deployments?** Start with the [CICD-SETUP-GUIDE.md](CICD-SETUP-GUIDE.md)! 🚀
