Guide: Getting GitLab On-Prem IDs & Tokens via UI
1■■ Getting Group ID
• Menu → Groups → Your Groups
• Select your Group (ex: onprem-projects)
• Go to Settings → General → Advanced
• Find the Group ID
2■■ Getting Project ID
• Menu → Projects → Your Projects
• Select your Project (ex: demo-repo)
• Go to Settings → General → Advanced
• Find the Project ID
3■■ Generate Personal Access Token (PAT)
• Profile Icon → Edit Profile → Access Tokens
• Set Scopes: api, read_repository, write_repository
• Create token and copy it
4■■ Get the Git Repository URL
• Open project → Click Clone button
• Copy the HTTP URL for mirroring
■ Summary
Group ID → Used in API & mirroring
Project ID → Required for repository targeting
Token → Authentication for automation & mirroring
Repo URL → Mirror target/source
Keep token secure! Do not share publicly
