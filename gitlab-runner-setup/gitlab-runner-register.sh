#!/bin/bash

# GitLab Runner Registration Script
# Registers the runner with GitLab.com

set -e

echo "================================================"
echo "GitLab Runner Registration Script"
echo "================================================"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root or with sudo" 
   exit 1
fi

# Prompt for GitLab URL
read -p "Enter GitLab URL [https://gitlab.com]: " GITLAB_URL
GITLAB_URL=${GITLAB_URL:-https://gitlab.com}

# Prompt for registration token
echo ""
echo "You can find your registration token at:"
echo "GitLab → Your Project → Settings → CI/CD → Runners → New project runner"
echo ""
read -p "Enter GitLab registration token: " REGISTRATION_TOKEN

if [ -z "$REGISTRATION_TOKEN" ]; then
    echo "Error: Registration token is required"
    exit 1
fi

# Prompt for runner description
read -p "Enter runner description [on-premise-runner]: " RUNNER_DESCRIPTION
RUNNER_DESCRIPTION=${RUNNER_DESCRIPTION:-on-premise-runner}

# Prompt for runner tags
read -p "Enter runner tags (comma-separated) [on-premise-runner,docker]: " RUNNER_TAGS
RUNNER_TAGS=${RUNNER_TAGS:-on-premise-runner,docker}

# Prompt for executor type
echo ""
echo "Available executors:"
echo "  1) docker (recommended)"
echo "  2) shell"
echo "  3) docker+machine"
read -p "Select executor [1]: " EXECUTOR_CHOICE
EXECUTOR_CHOICE=${EXECUTOR_CHOICE:-1}

case $EXECUTOR_CHOICE in
    1)
        EXECUTOR="docker"
        DEFAULT_IMAGE="docker:24-dind"
        ;;
    2)
        EXECUTOR="shell"
        DEFAULT_IMAGE=""
        ;;
    3)
        EXECUTOR="docker+machine"
        DEFAULT_IMAGE="docker:24-dind"
        ;;
    *)
        echo "Invalid choice. Using docker executor."
        EXECUTOR="docker"
        DEFAULT_IMAGE="docker:24-dind"
        ;;
esac

# Register the runner
echo ""
echo "Registering GitLab Runner..."
echo "================================================"

if [ "$EXECUTOR" = "docker" ] || [ "$EXECUTOR" = "docker+machine" ]; then
    gitlab-runner register \
        --non-interactive \
        --url "$GITLAB_URL" \
        --registration-token "$REGISTRATION_TOKEN" \
        --executor "$EXECUTOR" \
        --docker-image "$DEFAULT_IMAGE" \
        --docker-privileged \
        --docker-volumes /var/run/docker.sock:/var/run/docker.sock \
        --docker-volumes /cache \
        --description "$RUNNER_DESCRIPTION" \
        --tag-list "$RUNNER_TAGS" \
        --run-untagged="false" \
        --locked="false"
else
    gitlab-runner register \
        --non-interactive \
        --url "$GITLAB_URL" \
        --registration-token "$REGISTRATION_TOKEN" \
        --executor "$EXECUTOR" \
        --description "$RUNNER_DESCRIPTION" \
        --tag-list "$RUNNER_TAGS" \
        --run-untagged="false" \
        --locked="false"
fi

echo ""
echo "================================================"
echo "GitLab Runner registered successfully!"
echo "================================================"
echo ""
echo "Runner details:"
echo "  Description: $RUNNER_DESCRIPTION"
echo "  Tags: $RUNNER_TAGS"
echo "  Executor: $EXECUTOR"
echo ""
echo "Restarting GitLab Runner service..."
systemctl restart gitlab-runner

echo ""
echo "Checking runner status..."
gitlab-runner verify

echo ""
echo "Registration complete! Your runner is now active."
echo ""
