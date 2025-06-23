#!/usr/bin/env bash
#
# Donetick System Operations Library
# Functions for system-level operations
#

install_dependencies() {
  msg_info "Updating package lists and installing dependencies..."
  apt-get update >/dev/null
  apt-get install -y curl sqlite3 gpg ca-certificates openssl cron >/dev/null
  msg_ok "Dependencies installed successfully."
}

create_service_user() {
  msg_info "Creating system user '${SERVICE_USER}'..."
  if id "${SERVICE_USER}" &>/dev/null; then
    msg_warn "User '${SERVICE_USER}' already exists. Skipping creation."
  else
    useradd -r -s /bin/false -d "${INSTALL_DIR}" "${SERVICE_USER}"
    msg_ok "System user '${SERVICE_USER}' created."
  fi
}

get_system_architecture() {
  local arch=$(dpkg --print-architecture)
  local download_arch=""
  
  case $arch in
    amd64) download_arch="x86_64" ;;
    arm64) download_arch="arm64" ;;
    armhf) download_arch="armv7" ;;
    *) 
      msg_error "Unsupported architecture: ${arch}. Cannot continue."
      return 1
      ;;
  esac
  
  echo "$download_arch"
}

set_file_permissions() {
  msg_info "Setting file permissions and ownership..."
  
  # Set ownership on entire directory structure
  chown -R "${SERVICE_USER}":"${SERVICE_USER}" "${INSTALL_DIR}"
  
  # Set directory permissions
  chmod 750 "${INSTALL_DIR}"
  chmod 750 "${CONFIG_DIR}"
  
  # Set file permissions
  if [[ -f "${CONFIG_DIR}/selfhosted.yaml" ]]; then
    chmod 640 "${CONFIG_DIR}/selfhosted.yaml"
    chown "${SERVICE_USER}":"${SERVICE_USER}" "${CONFIG_DIR}/selfhosted.yaml"
  fi
  
  # Ensure binary is executable and owned correctly
  chmod +x "${INSTALL_DIR}/donetick"
  chown "${SERVICE_USER}":"${SERVICE_USER}" "${INSTALL_DIR}/donetick"
  
  # Ensure version file has correct ownership
  if [[ -f "${VERSION_FILE}" ]]; then
    chown "${SERVICE_USER}":"${SERVICE_USER}" "${VERSION_FILE}"
  fi
  
  msg_ok "Permissions and ownership set."
}

stop_service_if_running() {
  if systemctl is-active --quiet donetick; then
    msg_info "Donetick is running. Stopping service for update..."
    systemctl stop donetick
    msg_ok "Service stopped."
  fi
}

start_and_enable_service() {
  msg_info "Reloading systemd, enabling and starting Donetick service..."
  systemctl daemon-reload
  systemctl enable --now donetick
  
  # Wait a moment for service to start and set database ownership
  sleep 2
  
  # Set ownership on any database files that may have been created
  if [[ -f "${INSTALL_DIR}/donetick.db" ]]; then
    chown "${SERVICE_USER}":"${SERVICE_USER}" "${INSTALL_DIR}/donetick.db"
    msg_info "Database file ownership set"
  fi
  
  msg_ok "Donetick service started and enabled on boot."
}

create_credentials_file() {
  local version="$1"
  local is_update="$2"
  
  msg_info "Creating credentials and information file..."
  local ip_addr=$(hostname -I | awk '{print $1}')
  
  # Get JWT secret from config if it exists
  local jwt_secret="Check config file"
  if [[ -f "${CONFIG_DIR}/selfhosted.yaml" ]] && [[ "$is_update" == "false" ]]; then
    # Extract JWT secret from config if this was a fresh install
    jwt_secret=$(grep -A1 "jwt:" "${CONFIG_DIR}/selfhosted.yaml" | grep "secret:" | awk '{print $2}' | tr -d '"' 2>/dev/null || echo "Check config file")
  fi
  
  # Try to download credentials template
  local creds_template_url="${BASE_URL}/templates/donetick.creds"
  local temp_creds="/tmp/donetick.creds"
  
  if download_file "$creds_template_url" "$temp_creds" "credentials template"; then
    # Replace placeholders in template
    sed -e "s|\${VERSION}|${version}|g" \
        -e "s|\${IP_ADDR}|${ip_addr}|g" \
        -e "s|\${INSTALL_DIR}|${INSTALL_DIR}|g" \
        -e "s|\${CONFIG_DIR}|${CONFIG_DIR}|g" \
        -e "s|\${JWT_SECRET}|${jwt_secret}|g" \
        -e "s|\${UPDATER_SCRIPT}|${UPDATER_SCRIPT}|g" \
        -e "s|\${CRON_FILE}|${CRON_FILE}|g" \
        "$temp_creds" > /root/donetick.creds
    rm -f "$temp_creds"
  else
    # Fallback to embedded credentials file
    cat <<EOF > /root/donetick.creds
Donetick Installation Details
=============================
Version:      ${version}
Access URL:   http://${ip_addr}:2021
Install Dir:  ${INSTALL_DIR}
Config File:  ${CONFIG_DIR}/selfhosted.yaml
JWT Secret:   ${jwt_secret}

Service Management:
- Start:   systemctl start donetick
- Stop:    systemctl stop donetick
- Restart: systemctl restart donetick
- Status:  systemctl status donetick
- Logs:    journalctl -u donetick -f

Update Management:
- Check for updates:  ${UPDATER_SCRIPT} (or re-run this script with --check)
- Manual update:      Re-run this installation script
- Auto-update logs:   /var/log/donetick-updater.log
- Auto-update cron:   ${CRON_FILE}

To update, simply re-run this script or use: ${UPDATER_SCRIPT}
EOF
  fi
  
  msg_ok "Installation details saved to /root/donetick.creds"
}
