#!/bin/bash

# On-Prem GitLab Config
ON_PREM_URL="http://172.16.0.4"
ON_PREM_TOKEN="AdminApiToken123"
ON_PREM_PROJECT_ID="1"

# Cloud GitLab Config
CLOUD_URL="https://gitlab.com"
CLOUD_USERNAME="Prudhvi1802"  # ✅ Your GitLab username
CLOUD_TOKEN="glpat-hILdLaLA-RKsjpw2thUZ5m86MQp1OmluOTR0Cw.01.1212as4iy"
CLOUD_NAMESPACE="Prudhvi1802/demo-repo"  # ✅ Your project path

echo "Creating Push Mirror from On-Prem → GitLab.com"
echo "-------------------------------------------------"

response=$(curl -s --request POST "$ON_PREM_URL/api/v4/projects/$ON_PREM_PROJECT_ID/remote_mirrors" \
  --header "PRIVATE-TOKEN: $ON_PREM_TOKEN" \
  --data "url=$CLOUD_URL/$CLOUD_NAMESPACE.git" \
  --data "enabled=true" \
  --data "only_protected_branches=false" \
  --data "user=$CLOUD_USERNAME" \
  --data "password=$CLOUD_TOKEN")

echo "$response"
echo "-------------------------------------------------"

if echo "$response" | grep -q '"id"'; then
  echo "✅ Push mirroring successfully configured!"
else
  echo "❌ Failed to create mirroring! Check values again."
fi

echo "-------------------------------------------------"
