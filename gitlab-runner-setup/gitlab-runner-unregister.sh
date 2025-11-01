#!/bin/bash

# GitLab Runner Unregistration Script

set -e

echo "================================================"
echo "GitLab Runner Unregistration Script"
echo "================================================"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root or with sudo" 
   exit 1
fi

# List all runners
echo "Current runners:"
gitlab-runner list

echo ""
read -p "Enter the runner name to unregister (or 'all' for all runners): " RUNNER_NAME

if [ "$RUNNER_NAME" = "all" ]; then
    echo "Unregistering all runners..."
    gitlab-runner unregister --all-runners
else
    echo "Unregistering runner: $RUNNER_NAME"
    gitlab-runner unregister --name "$RUNNER_NAME"
fi

echo ""
echo "Runner(s) unregistered successfully!"
gitlab-runner list
