#!/usr/bin/env bash
#
# Donetick Service Management Library
# Functions for managing systemd service
#

create_systemd_service() {
  msg_info "Creating systemd service..."
  
  # Try to download service template first
  local service_template_url="${BASE_URL}/templates/donetick.service"
  local temp_service="/tmp/donetick.service"
  
  if download_file "$service_template_url" "$temp_service" "service template"; then
    # Replace placeholders in template
    sed -e "s|\${SERVICE_USER}|${SERVICE_USER}|g" \
        -e "s|\${INSTALL_DIR}|${INSTALL_DIR}|g" \
        -e "s|\${CONFIG_DIR}|${CONFIG_DIR}|g" \
        "$temp_service" > "${SERVICE_FILE}"
    rm -f "$temp_service"
  else
    # Fallback to embedded service file
    create_embedded_service
  fi
  
  msg_ok "Systemd service file created at ${SERVICE_FILE}"
}

create_embedded_service() {
  cat <<EOF > "${SERVICE_FILE}"
[Unit]
Description=Donetick Task Manager
After=network.target
Wants=network.target

[Service]
Type=simple
User=${SERVICE_USER}
Group=${SERVICE_USER}
WorkingDirectory=${INSTALL_DIR}
ExecStart=${INSTALL_DIR}/donetick
Environment="DT_ENV=selfhosted"
Environment="DT_CONFIG_PATH=${CONFIG_DIR}/selfhosted.yaml"
Restart=always
RestartSec=5

# Security Hardening
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/opt/donetick/config /opt/donetick
CapabilityBoundingSet=
AmbientCapabilities=
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true

[Install]
WantedBy=multi-user.target
EOF
}

setup_automatic_updates() {
  msg_info "Setting up automatic updates..."
  
  # Download updater script template
  local updater_url="${BASE_URL}/scripts/auto-updater.sh"
  if download_file "$updater_url" "${UPDATER_SCRIPT}" "auto-updater script"; then
    chmod +x "${UPDATER_SCRIPT}"
  else
    msg_error "Failed to download auto-updater script"
  fi
  
  # Create cron job (runs daily at 3 AM)
  local cron_template_url="${BASE_URL}/templates/donetick-cron"
  local temp_cron="/tmp/donetick-cron"
  
  if download_file "$cron_template_url" "$temp_cron" "cron template"; then
    # Replace placeholders in template
    sed "s|\${UPDATER_SCRIPT}|${UPDATER_SCRIPT}|g" "$temp_cron" > "${CRON_FILE}"
    rm -f "$temp_cron"
  else
    # Fallback to embedded cron job
    cat <<EOF > "${CRON_FILE}"
# Donetick Automatic Updates
# Runs daily at 3:00 AM to check for and install updates
0 3 * * * root ${UPDATER_SCRIPT} >/dev/null 2>&1
EOF
  fi
  
  # Ensure cron service is enabled
  if command -v systemctl >/dev/null 2>&1; then
    systemctl enable cron >/dev/null 2>&1 || systemctl enable cronie >/dev/null 2>&1 || true
  fi
  
  msg_ok "Automatic updates configured (daily at 3:00 AM)"
  msg_info "Logs will be written to: /var/log/donetick-updater.log"
}
