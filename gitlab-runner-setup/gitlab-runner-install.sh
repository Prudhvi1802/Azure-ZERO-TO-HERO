#!/bin/bash

# GitLab Runner Installation Script for Ubuntu/Debian
# This script automates the complete installation of GitLab Runner

set -e

echo "================================================"
echo "GitLab Runner Installation Script"
echo "================================================"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root or with sudo" 
   exit 1
fi

# Update system packages
echo "Updating system packages..."
apt-get update -y
apt-get upgrade -y

# Install required dependencies
echo "Installing dependencies..."
apt-get install -y curl ca-certificates apt-transport-https software-properties-common

# Add GitLab official repository
echo "Adding GitLab Runner repository..."
curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh" | bash

# Install GitLab Runner
echo "Installing GitLab Runner..."
apt-get install -y gitlab-runner

# Install Docker (required for Docker executor)
echo "Installing Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# Add gitlab-runner user to docker group
usermod -aG docker gitlab-runner

# Enable and start Docker
systemctl enable docker
systemctl start docker

# Enable and start GitLab Runner
systemctl enable gitlab-runner
systemctl start gitlab-runner

# Verify installation
echo ""
echo "Verifying GitLab Runner installation..."
gitlab-runner --version

echo ""
echo "Verifying Docker installation..."
docker --version

echo ""
echo "================================================"
echo "GitLab Runner installed successfully!"
echo "================================================"
echo ""
echo "Next steps:"
echo "1. Run ./gitlab-runner-register.sh to register the runner"
echo "2. Obtain your GitLab registration token from:"
echo "   GitLab.com → Your Project → Settings → CI/CD → Runners"
echo ""
