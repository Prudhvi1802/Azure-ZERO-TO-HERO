# ---------------------------
# Reconfigure GitLab
# ---------------------------
echo "Reconfiguring GitLab (this will apply the registry config)..."
sudo gitlab-ctl reconfigure

# Wait briefly and show registry status
echo "Restarting GitLab services for good measure..."
sudo gitlab-ctl restart

echo
echo "======================================================"
echo "✅ Container Registry should be available at:"
echo "   https://${GITLAB_HOSTNAME}:${REGISTRY_PORT}"
echo
echo "Notes / Next steps (read carefully):"
echo "1) Docker clients must trust the registry TLS certificate."
echo "   - For Ubuntu/Debian Docker hosts, copy the certificate to:"
echo "       /etc/docker/certs.d/${GITLAB_HOSTNAME}:${REGISTRY_PORT}/ca.crt"
echo "     then restart docker: sudo systemctl restart docker"
echo
echo "   - If using an internal CA, install the CA cert instead of a self-signed cert."
echo
echo "2) Test login from a client that resolves ${GITLAB_HOSTNAME}:"
echo "     docker login ${GITLAB_HOSTNAME}:${REGISTRY_PORT}"
echo "   Use your GitLab username and a Personal Access Token (or read GitLab docs about deploying credentials)."
echo
echo "3) Example push flow:"
echo "     docker tag myimage:latest ${GITLAB_HOSTNAME}:${REGISTRY_PORT}/mygroup/myimage:latest"
echo "     docker push ${GITLAB_HOSTNAME}:${REGISTRY_PORT}/mygroup/myimage:latest"
echo
echo "4) Backup: your registry data lives under the omnibus-managed directories (usually /var/opt/gitlab/registry)."
echo
echo "If you plan to replace the self-signed cert with an internal-CA cert, copy the CA-signed cert/key to ${CERT_FILE} / ${KEY_FILE} and run:"
echo "   sudo gitlab-ctl reconfigure && sudo gitlab-ctl restart"
echo
echo "Backup of modified files is stored in: ${BACKUP_DIR}"
echo "======================================================"
