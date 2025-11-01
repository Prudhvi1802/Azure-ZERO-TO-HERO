#!/bin/bash

# =================================================================
# CONFIGURATION USING LOCAL HOSTNAME
# We retrieve the server's hostname (e.g., 'gitlab-server')
# This requires users on your network to be able to resolve this name
# (via DNS or their local 'hosts' file).
# =================================================================
GITLAB_HOSTNAME=$(hostname)
EXTERNAL_URL_CONFIG="http://${GITLAB_HOSTNAME}"

echo "Starting GitLab CE installation."
echo "External URL will be set to the server's hostname: ${EXTERNAL_URL_CONFIG}"
echo "--------------------------------------------------------"

# Update packages and install prerequisites
sudo apt update
sudo apt install -y curl openssh-server ca-certificates

# Open firewall
echo "Configuring firewall..."
sudo ufw allow http
sudo ufw allow https
sudo ufw allow ssh
sudo ufw --force enable

# Add GitLab package repository
echo "Adding GitLab package repository..."
curl "https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.deb.sh" | sudo bash

# Install GitLab CE (Community Edition)
echo "Installing GitLab CE..."
sudo EXTERNAL_URL="${EXTERNAL_URL_CONFIG}" apt install -y gitlab-ce

echo "--------------------------------------------------------"
echo "Installation complete!"
echo "Access your GitLab instance at: ${EXTERNAL_URL_CONFIG}"
