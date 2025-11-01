#!/bin/bash

# GitLab Runner Health Check Script

echo "================================================"
echo "GitLab Runner Health Check"
echo "================================================"
echo ""

# Check if gitlab-runner is installed
if ! command -v gitlab-runner &> /dev/null; then
    echo "❌ GitLab Runner is not installed"
    exit 1
else
    echo "✅ GitLab Runner is installed"
    gitlab-runner --version
fi

echo ""
echo "Checking GitLab Runner service status..."
if systemctl is-active --quiet gitlab-runner; then
    echo "✅ GitLab Runner service is running"
else
    echo "❌ GitLab Runner service is not running"
fi

echo ""
echo "Registered runners:"
sudo gitlab-runner list

echo ""
echo "Verifying runner configuration..."
sudo gitlab-runner verify

echo ""
echo "Docker status:"
if systemctl is-active --quiet docker; then
    echo "✅ Docker service is running"
    docker --version
else
    echo "❌ Docker service is not running"
fi

echo ""
echo "Checking Docker permissions for gitlab-runner user..."
if groups gitlab-runner | grep -q docker; then
    echo "✅ gitlab-runner user is in docker group"
else
    echo "❌ gitlab-runner user is NOT in docker group"
    echo "   Run: sudo usermod -aG docker gitlab-runner"
fi

echo ""
echo "Recent GitLab Runner logs:"
sudo journalctl -u gitlab-runner -n 20 --no-pager

echo ""
echo "================================================"
echo "Health check complete!"
echo "================================================"
