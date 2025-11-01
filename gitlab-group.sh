#!/bin/bash

# ==============================
# CONFIGURATION
# ==============================
GITLAB_URL="http://172.16.0.4"
TOKEN="AdminApiToken123"  # Root API Token

# Customize your group details
GROUP_NAME="onprem-projects"
GROUP_PATH="onprem-projects"
VISIBILITY="private"  # private | internal | public

echo "Creating GitLab Group: $GROUP_NAME"
echo "-------------------------------------------------"

# API call to create new group
RESPONSE=$(curl -s -X POST \
  --header "PRIVATE-TOKEN: $TOKEN" \
  "$GITLAB_URL/api/v4/groups" \
  --data "name=$GROUP_NAME" \
  --data "path=$GROUP_PATH" \
  --data "visibility=$VISIBILITY")

echo "Response:"
echo "$RESPONSE"

# Extract ID to confirm success
GROUP_ID=$(echo "$RESPONSE" | jq '.id')

echo "-------------------------------------------------"
if [ "$GROUP_ID" = "null" ] || [ -z "$GROUP_ID" ]; then
  echo "❌ Group creation failed. Check token or GitLab logs."
else
  echo "✅ GitLab group created successfully!"
  echo "Group ID: $GROUP_ID"
fi
echo "-------------------
