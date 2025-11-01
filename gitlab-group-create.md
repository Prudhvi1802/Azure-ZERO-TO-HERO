GitLab On-Prem to Cloud Integration - UI Method
1. Create Group via GitLab On-Prem UI:
- Login to GitLab: http://172.16.0.4
- Go to Groups → New Group
- Group Name: onprem-projects
- Group Path: onprem-projects
- Visibility: Private
- Click Create Group
- Group ID visible inside Group Settings or URL
2. Generate Personal Access Token via UI:
- Click on Profile icon → Edit Profile
- Select Access Tokens
- Scopes Required:
- api
- read_api
- read_repository
- write_repository
- Save and copy token
3. Use Token & Group ID in mirror scripts:
- TOKEN = generated token
- GROUP_ID from UI details
This document describes UI method equivalent to automated scripts.
