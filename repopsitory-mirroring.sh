#!/bin/bash

# ==========================
# Configuration Variables
# ==========================
ON_PREM_GITLAB_URL="http://172.16.0.4"
ON_PREM_GROUP_ID="1"   # Change this to your group ID

GITLAB_COM_URL="https://gitlab.com"
GITLAB_COM_GROUP_ID="12345678"   # Change this to your GitLab.com group ID
GITLAB_COM_TOKEN="YOUR_GITLAB_COM_TOKEN"  # Replace this securely

# ==========================
# Fetch list of projects
# ==========================
echo "Fetching On-Prem Project List..."
PROJECTS=$(curl -s --header "PRIVATE-TOKEN: $(sudo cat /etc/gitlab/initial_root_password)" \
    "$ON_PREM_GITLAB_URL/api/v4/groups/$ON_PREM_GROUP_ID/projects" | jq -r '.[].id')

# ==========================
# Configure mirroring
# ==========================
for PROJECT_ID in $PROJECTS; do
    PROJECT_NAME=$(curl -s --header "PRIVATE-TOKEN: $(sudo cat /etc/gitlab/initial_root_password)" \
        "$ON_PREM_GITLAB_URL/api/v4/projects/$PROJECT_ID" | jq -r '.name')

    MIRROR_URL="$GITLAB_COM_URL/$GITLAB_COM_GROUP_ID/$PROJECT_NAME.git"

    echo "Setting up mirroring for $PROJECT_NAME..."

    curl -s --request POST \
      --header "PRIVATE-TOKEN: $(sudo cat /etc/gitlab/initial_root_password)" \
      "$ON_PREM_GITLAB_URL/api/v4/projects/$PROJECT_ID/remote_mirrors" \
      --data "url=$MIRROR_URL" \
      --data "enabled=true" \
      --data "only_protected_branches=false" \
      --data "keep_divergent_refs=true" \
      --data "authentication_method=password" \
      --data "password=$GITLAB_COM_TOKEN" > /dev/null

    echo "✅ Mirroring enabled: $PROJECT_NAME -> GitLab.com"
done

echo "=============================================================="
echo "✅ Repository mirroring setup complete for all group projects!"
echo "=============================================================="
----------------------------------------------------------------------------------------------------------------------------------
chmod +x mirror_setup.sh
./mirror_setup.sh
sudo crontab -e
*/15 * * * * /root/mirror_setup.sh   #to run every 15minutes, alternativy we can change the sync depends upon our time requirement
