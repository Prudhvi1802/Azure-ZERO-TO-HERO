# GitLab Runner Setup Guide

Complete automated setup scripts for installing and configuring GitLab Runner on your on-premises VM.

## 📋 Prerequisites

- Ubuntu/Debian-based Linux VM in your data center
- Root or sudo access
- Internet connectivity to reach GitLab.com
- At least 2GB RAM and 20GB disk space
- Ports 443 (HTTPS) open for outbound connections

## 📂 Files Overview

| File | Purpose |
|------|---------|
| `gitlab-runner-install.sh` | Install GitLab Runner and Docker |
| `gitlab-runner-register.sh` | Register runner with GitLab.com |
| `gitlab-runner-unregister.sh` | Remove runner registration |
| `gitlab-runner-check.sh` | Health check and status verification |

## 🚀 Quick Start

### Step 1: Transfer Scripts to Your VM

```bash
# From your local machine, copy scripts to VM
scp -r gitlab-runner-setup/ user@your-vm-ip:~/

# SSH into your VM
ssh user@your-vm-ip

# Navigate to directory
cd ~/gitlab-runner-setup
```

### Step 2: Make Scripts Executable

```bash
chmod +x *.sh
```

### Step 3: Install GitLab Runner

```bash
sudo ./gitlab-runner-install.sh
```

**What this does:**
- Updates system packages
- Installs GitLab Runner from official repository
- Installs Docker and Docker daemon
- Configures gitlab-runner user with Docker permissions
- Starts and enables services

**Expected output:**
```
✅ GitLab Runner version X.X.X installed
✅ Docker version X.X.X installed
✅ Services started and enabled
```

### Step 4: Get Registration Token from GitLab

1. Go to [GitLab.com](https://gitlab.com)
2. Navigate to your project
3. Go to **Settings → CI/CD → Runners**
4. Click **"New project runner"** or **"Register a project runner"**
5. Copy the registration token (starts with `glrt-`)

### Step 5: Register the Runner

```bash
sudo ./gitlab-runner-register.sh
```

**Interactive prompts:**
```
Enter GitLab URL [https://gitlab.com]: <press Enter>
Enter GitLab registration token: glrt-xxxxxxxxxxxxxxxxxxxx
Enter runner description [on-premise-runner]: <press Enter or custom name>
Enter runner tags (comma-separated) [on-premise-runner,docker]: <press Enter>
Select executor [1]: 1
```

**Recommended configuration:**
- **Executor**: docker (option 1)
- **Tags**: on-premise-runner,docker
- **Description**: on-premise-runner or your custom name

### Step 6: Verify Installation

```bash
./gitlab-runner-check.sh
```

**What this checks:**
- ✅ GitLab Runner installation
- ✅ Service status
- ✅ Docker installation
- ✅ Runner registration
- ✅ User permissions
- 📜 Recent logs

## 🔧 Configuration

### Runner Configuration File

Location: `/etc/gitlab-runner/config.toml`

**View configuration:**
```bash
sudo cat /etc/gitlab-runner/config.toml
```

**Common customizations:**

```toml
concurrent = 4  # Number of concurrent jobs (adjust based on VM resources)

[[runners]]
  name = "on-premise-runner"
  url = "https://gitlab.com"
  token = "YOUR_TOKEN"
  executor = "docker"
  
  [runners.docker]
    tls_verify = false
    image = "docker:24-dind"
    privileged = true
    disable_cache = false
    volumes = ["/var/run/docker.sock:/var/run/docker.sock", "/cache"]
    shm_size = 0
    pull_policy = "if-not-present"
```

**After editing, restart:**
```bash
sudo systemctl restart gitlab-runner
```

### Adjust Concurrent Jobs

Based on your VM resources:
- **2 CPU cores, 4GB RAM**: `concurrent = 2`
- **4 CPU cores, 8GB RAM**: `concurrent = 4`
- **8+ CPU cores, 16GB+ RAM**: `concurrent = 8`

Edit `/etc/gitlab-runner/config.toml` and change the `concurrent` value.

## 🔍 Monitoring & Troubleshooting

### Check Runner Status

```bash
# List all runners
sudo gitlab-runner list

# Verify runner connection
sudo gitlab-runner verify

# Check service status
sudo systemctl status gitlab-runner
```

### View Logs

```bash
# Real-time logs
sudo journalctl -u gitlab-runner -f

# Last 50 lines
sudo journalctl -u gitlab-runner -n 50

# Logs from last hour
sudo journalctl -u gitlab-runner --since "1 hour ago"
```

### Common Issues

#### ❌ Runner not appearing in GitLab

**Solution:**
```bash
# Verify registration
sudo gitlab-runner verify

# Restart service
sudo systemctl restart gitlab-runner

# Check logs for errors
sudo journalctl -u gitlab-runner -n 50
```

#### ❌ Docker permission denied

**Solution:**
```bash
# Add gitlab-runner to docker group
sudo usermod -aG docker gitlab-runner

# Restart runner
sudo systemctl restart gitlab-runner
```

#### ❌ Jobs stuck in pending

**Possible causes:**
- Runner is offline
- Job tags don't match runner tags
- Runner is paused in GitLab

**Check:**
```bash
./gitlab-runner-check.sh
```

## 🔐 Security Best Practices

1. **Restrict Runner to Specific Projects**
   - In GitLab: Settings → CI/CD → Runners → Enable for this project only

2. **Use Protected Branches**
   - In GitLab: Settings → CI/CD → Variables → Mark as "Protected"
   - Runner will only run on protected branches

3. **Limit Runner Permissions**
   - Use specific tags
   - Set `run-untagged="false"`
   - Configure project-specific runners

4. **Regular Updates**
   ```bash
   sudo apt-get update
   sudo apt-get upgrade gitlab-runner
   ```

## 📊 Resource Management

### Monitor Resource Usage

```bash
# CPU and memory usage
top

# Docker resource usage
docker stats

# Disk space
df -h
```

### Clean Up Docker Resources

```bash
# Remove unused images
docker image prune -a

# Remove stopped containers
docker container prune

# Clean everything
docker system prune -a --volumes
```

## 🔄 Updating GitLab Runner

```bash
# Update runner
sudo apt-get update
sudo apt-get install gitlab-runner

# Restart service
sudo systemctl restart gitlab-runner

# Verify version
gitlab-runner --version
```

## ❌ Uninstalling

### Unregister Runner First

```bash
sudo ./gitlab-runner-unregister.sh
# Select 'all' to unregister all runners
```

### Then Uninstall

```bash
# Stop service
sudo systemctl stop gitlab-runner

# Uninstall GitLab Runner
sudo apt-get remove gitlab-runner

# Remove configuration
sudo rm -rf /etc/gitlab-runner

# Optional: Remove Docker
sudo apt-get remove docker docker-engine docker.io containerd runc
```

## 📞 Support

If you encounter issues:

1. Run health check: `./gitlab-runner-check.sh`
2. Check logs: `sudo journalctl -u gitlab-runner -n 100`
3. Verify GitLab connectivity: `curl https://gitlab.com`
4. Review [GitLab Runner docs](https://docs.gitlab.com/runner/)

## 🔗 Next Steps

After successful installation:

1. ✅ **Configure SonarQube** - Code quality analysis
2. ✅ **Set up Kubernetes access** - For deployments
3. ✅ **Create .gitlab-ci.yml** - Define your CI/CD pipeline
4. ✅ **Configure GitLab CI/CD variables** - Store secrets

---

**Ready to proceed?** The runner is now ready to execute your CI/CD pipelines!
