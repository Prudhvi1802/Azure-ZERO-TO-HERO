# How to Execute Scripts on Azure VMs

Complete guide for transferring and running Kubernetes setup scripts on your Azure virtual machines.

---

## 📋 Table of Contents

1. [Prerequisites](#prerequisites)
2. [Method 1: Using SCP (Recommended)](#method-1-using-scp-recommended)
3. [Method 2: Using Git](#method-2-using-git)
4. [Method 3: Using Azure Portal/Cloud Shell](#method-3-using-azure-portalcloud-shell)
5. [Method 4: Copy-Paste (Small Scripts)](#method-4-copy-paste-small-scripts)
6. [Complete Execution Workflow](#complete-execution-workflow)
7. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### On Your Windows Machine

- ✅ SSH client installed (built-in on Windows 10/11)
- ✅ Azure CLI installed (optional, for Method 3)
- ✅ Git installed (optional, for Method 2)
- ✅ SCP/SFTP client (built-in with SSH)

### On Your Azure VMs

- ✅ SSH access configured
- ✅ Public IP addresses assigned
- ✅ SSH port (22) open in NSG (Network Security Group)
- ✅ User with sudo privileges (e.g., azureuser)

### Get VM Information

You'll need:
- **Master VM IP**: `<master-ip>`
- **Worker VM IP**: `<worker-ip>`
- **SSH Username**: Usually `azureuser`
- **SSH Key or Password**: For authentication

---

## Method 1: Using SCP (Recommended)

### Step 1: Open PowerShell or Command Prompt

```powershell
# Navigate to your project directory
cd C:\Users\GKumar5\Desktop\temporary\Azure-ZERO-TO-HERO
```

### Step 2: Transfer Files to Master VM

```powershell
# Transfer all script files to master VM
scp prerequisites.sh init-master.sh master-node.sh verify-cluster.sh azureuser@<master-ip>:~/

# Example:
scp prerequisites.sh init-master.sh master-node.sh verify-cluster.sh azureuser@20.10.30.40:~/
```

**If using SSH key:**
```powershell
scp -i C:\path\to\your-key.pem prerequisites.sh init-master.sh master-node.sh verify-cluster.sh azureuser@<master-ip>:~/
```

### Step 3: Transfer Files to Worker VM

```powershell
# Transfer worker-specific files
scp prerequisites.sh init-worker.sh worker-node.sh join-nodes.sh azureuser@<worker-ip>:~/

# Example:
scp prerequisites.sh init-worker.sh worker-node.sh join-nodes.sh azureuser@20.10.30.41:~/
```

### Step 4: Connect to VM via SSH

```powershell
# Connect to master VM
ssh azureuser@<master-ip>

# Or with SSH key
ssh -i C:\path\to\your-key.pem azureuser@<master-ip>
```

### Step 5: Verify Files are Transferred

```bash
# Once connected to VM, check files
ls -la ~/*.sh

# You should see:
# -rw-r--r-- 1 azureuser azureuser  xxxx prerequisites.sh
# -rw-r--r-- 1 azureuser azureuser  xxxx init-master.sh
# etc.
```

### Step 6: Make Scripts Executable

```bash
# Make all scripts executable
chmod +x *.sh

# Verify permissions changed
ls -la ~/*.sh

# Now you should see:
# -rwxr-xr-x 1 azureuser azureuser  xxxx prerequisites.sh
# -rwxr-xr-x 1 azureuser azureuser  xxxx init-master.sh
```

### Step 7: Run the Scripts

```bash
# Run prerequisites first
sudo ./prerequisites.sh

# After reboot, initialize master
sudo ./init-master.sh

# Verify cluster
sudo ./master-node.sh
```

---

## Method 2: Using Git

### On Master VM

```bash
# Connect to VM
ssh azureuser@<master-ip>

# Clone the repository
cd ~
git clone https://github.com/Prudhvi1802/Azure-ZERO-TO-HERO.git

# Navigate to directory
cd Azure-ZERO-TO-HERO

# Make scripts executable
chmod +x *.sh

# Run scripts
sudo ./prerequisites.sh
```

### On Worker VM

```bash
# Connect to VM
ssh azureuser@<worker-ip>

# Clone the repository
cd ~
git clone https://github.com/Prudhvi1802/Azure-ZERO-TO-HERO.git

# Navigate to directory
cd Azure-ZERO-TO-HERO

# Make scripts executable
chmod +x *.sh

# Run scripts
sudo ./prerequisites.sh
```

---

## Method 3: Using Azure Portal/Cloud Shell

### Via Azure Cloud Shell

1. **Open Azure Portal** (https://portal.azure.com)

2. **Open Cloud Shell** (icon at top right)

3. **Upload files to Cloud Shell:**
   ```bash
   # In Cloud Shell, create a directory
   mkdir -p k8s-scripts
   cd k8s-scripts
   ```

4. **Upload files using Cloud Shell upload button** or:
   ```bash
   # Use curl to download from GitHub
   curl -O https://raw.githubusercontent.com/Prudhvi1802/Azure-ZERO-TO-HERO/main/prerequisites.sh
   curl -O https://raw.githubusercontent.com/Prudhvi1802/Azure-ZERO-TO-HERO/main/init-master.sh
   # ... etc
   ```

5. **Copy files to VMs:**
   ```bash
   # From Cloud Shell to Master VM
   scp *.sh azureuser@<master-ip>:~/
   
   # From Cloud Shell to Worker VM
   scp prerequisites.sh init-worker.sh worker-node.sh azureuser@<worker-ip>:~/
   ```

---

## Method 4: Copy-Paste (Small Scripts)

### For Quick Testing or Small Scripts

1. **Connect to VM via SSH:**
   ```powershell
   ssh azureuser@<master-ip>
   ```

2. **Create file using nano or vi:**
   ```bash
   nano init-master.sh
   ```

3. **Paste the script content** (Ctrl+V or right-click)

4. **Save and exit:**
   - In nano: `Ctrl+X`, then `Y`, then `Enter`
   - In vi: `Esc`, then `:wq`, then `Enter`

5. **Make executable:**
   ```bash
   chmod +x init-master.sh
   ```

---

## Complete Execution Workflow

### Master Node Setup

```bash
# 1. Connect to Master VM
ssh azureuser@<master-ip>

# 2. Verify files are present
ls -la ~/*.sh

# 3. Make scripts executable (if not already)
chmod +x *.sh

# 4. Run prerequisites
sudo ./prerequisites.sh

# 5. IMPORTANT: Reboot after prerequisites
sudo reboot

# 6. Reconnect after reboot
ssh azureuser@<master-ip>

# 7. Initialize master node (auto-detect IP)
sudo ./init-master.sh

# OR specify IP explicitly
sudo ./init-master.sh 10.0.1.10

# 8. Script will display join command - COPY IT!
# Example output:
# kubeadm join 10.0.1.10:6443 --token abc123.xyz789 \
#   --discovery-token-ca-cert-hash sha256:1234567890abcdef...

# 9. Verify cluster
sudo ./master-node.sh
```

### Worker Node Setup

```bash
# 1. Connect to Worker VM
ssh azureuser@<worker-ip>

# 2. Verify files are present
ls -la ~/*.sh

# 3. Make scripts executable (if not already)
chmod +x *.sh

# 4. Run prerequisites
sudo ./prerequisites.sh

# 5. IMPORTANT: Reboot after prerequisites
sudo reboot

# 6. Reconnect after reboot
ssh azureuser@<worker-ip>

# 7. Join cluster using the command from master
sudo ./init-worker.sh kubeadm join 10.0.1.10:6443 --token abc123.xyz789 \
    --discovery-token-ca-cert-hash sha256:1234567890abcdef...

# OR run interactively and paste when prompted
sudo ./init-worker.sh

# 8. Verify from master node
# (On master VM)
kubectl get nodes -o wide
```

---

## Troubleshooting

### Permission Denied Error

```bash
# Error: bash: ./script.sh: Permission denied

# Solution: Make script executable
chmod +x script.sh
```

### No Such File or Directory

```bash
# Error: No such file or directory

# Solution: Check file location
pwd                    # Shows current directory
ls -la                 # Lists all files
cd ~/                  # Go to home directory
ls -la *.sh           # Look for scripts
```

### Script Not Found

```bash
# Error: script.sh: command not found

# Solution: Use ./ prefix
sudo ./script.sh      # Correct
sudo script.sh        # Wrong
```

### SSH Connection Issues

```bash
# Error: Connection refused or timeout

# Solutions:
# 1. Check VM is running in Azure Portal
# 2. Verify NSG rules allow SSH (port 22)
# 3. Check you're using correct IP address
# 4. Verify SSH key or password

# Test connection
ping <vm-ip>
ssh -v azureuser@<vm-ip>  # Verbose output for debugging
```

### SCP Transfer Issues

```bash
# Error: Permission denied (publickey)

# Solution: Use password authentication
scp -o PreferredAuthentications=password prerequisites.sh azureuser@<vm-ip>:~/

# Or specify correct key
scp -i ~/.ssh/your-key.pem prerequisites.sh azureuser@<vm-ip>:~/
```

### Script Fails Due to Missing Sudo

```bash
# Error: This script must be run as root

# Solution: Use sudo
sudo ./script.sh
```

### Line Ending Issues (Windows to Linux)

```bash
# Error: /bin/bash^M: bad interpreter

# Solution: Convert line endings
sudo apt-get install dos2unix
dos2unix script.sh
```

---

## Quick Reference Commands

### File Transfer
```bash
# Single file
scp file.sh user@host:~/

# Multiple files
scp *.sh user@host:~/

# Entire directory
scp -r directory/ user@host:~/

# With SSH key
scp -i key.pem file.sh user@host:~/
```

### SSH Connection
```bash
# Basic connection
ssh user@host

# With SSH key
ssh -i key.pem user@host

# With custom port
ssh -p 2222 user@host

# Execute command remotely
ssh user@host "ls -la"
```

### File Management
```bash
# List files
ls -la

# Make executable
chmod +x script.sh

# Make all scripts executable
chmod +x *.sh

# Check file permissions
ls -l script.sh

# Remove file
rm script.sh

# Move/rename file
mv old.sh new.sh
```

### Script Execution
```bash
# Run with sudo
sudo ./script.sh

# Run with arguments
sudo ./script.sh arg1 arg2

# Run in background
sudo ./script.sh &

# Check running processes
ps aux | grep script.sh
```

---

## Best Practices

1. ✅ **Always test on one VM first** before deploying to all VMs
2. ✅ **Keep backups** of working scripts
3. ✅ **Use version control** (Git) for script management
4. ✅ **Document changes** you make to scripts
5. ✅ **Use sudo** only when necessary
6. ✅ **Verify script permissions** before execution
7. ✅ **Check logs** if scripts fail: `journalctl -xe`
8. ✅ **Read script output** carefully for errors
9. ✅ **Reboot after prerequisites** installation
10. ✅ **Save join command** from master initialization

---

## Complete Example Session

```bash
# === ON YOUR WINDOWS MACHINE ===

# Transfer files
cd C:\Users\GKumar5\Desktop\temporary\Azure-ZERO-TO-HERO
scp prerequisites.sh init-master.sh master-node.sh azureuser@20.10.30.40:~/

# === ON MASTER VM ===

# Connect
ssh azureuser@20.10.30.40

# Verify files
ls -la ~/*.sh

# Make executable
chmod +x *.sh

# Run prerequisites
sudo ./prerequisites.sh
# ... wait for completion ...

# Reboot
sudo reboot

# Reconnect after ~2 minutes
ssh azureuser@20.10.30.40

# Initialize master
sudo ./init-master.sh 20.10.30.40

# Copy the join command from output!
# Example: kubeadm join 20.10.30.40:6443 --token xyz...

# Verify
sudo ./master-node.sh

# === ON WORKER VM ===

# Transfer files (from Windows machine)
scp prerequisites.sh init-worker.sh azureuser@20.10.30.41:~/

# Connect
ssh azureuser@20.10.30.41

# Make executable
chmod +x *.sh

# Prerequisites
sudo ./prerequisites.sh

# Reboot
sudo reboot

# Reconnect
ssh azureuser@20.10.30.41

# Join cluster (paste join command from master)
sudo ./init-worker.sh kubeadm join 20.10.30.40:6443 --token xyz...

# === VERIFY ON MASTER ===

kubectl get nodes -o wide
kubectl get pods --all-namespaces
```

---

## Additional Resources

- **Azure VM Documentation**: https://docs.microsoft.com/en-us/azure/virtual-machines/
- **SSH Documentation**: https://www.ssh.com/academy/ssh
- **SCP Documentation**: https://www.ssh.com/academy/ssh/scp
- **Linux File Permissions**: https://www.linux.com/training-tutorials/understanding-linux-file-permissions/

---

**Last Updated**: October 2025
