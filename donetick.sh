#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2021-2025 community-scripts ORG
# Author: assistant | Based on firefly.sh by quantumryuu
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE

# Source: https://github.com/donetick/donetick

APP="Donetick"
var_tags="${var_tags:-productivity}"
var_cpu="${var_cpu:-1}"
var_ram="${var_ram:-1024}"
var_disk="${var_disk:-4}"
var_os="${var_os:-debian}"
var_version="${var_version:-12}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if [[ ! -d /opt/donetick ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi
  
  RELEASE=$(curl -fsSL https://api.github.com/repos/donetick/donetick/releases/latest | grep "tag_name" | awk '{print substr($2, 2, length($2)-3)}')
  if [[ ! -f /opt/${APP}_version.txt ]] || [[ "${RELEASE}" != "$(cat /opt/${APP}_version.txt)" ]]; then
    msg_info "Stopping ${APP}"
    systemctl stop donetick
    msg_ok "Stopped ${APP}"

    msg_info "Backing up configuration"
    cp /opt/donetick/config/selfhosted.yaml /opt/selfhosted.yaml.backup
    msg_ok "Backed up configuration"

    msg_info "Updating ${APP} to ${RELEASE}"
    cd /opt/donetick
    
    # Download the latest release
    ARCH=$(dpkg --print-architecture)
    case $ARCH in
      amd64) DOWNLOAD_ARCH="amd64" ;;
      arm64) DOWNLOAD_ARCH="arm64" ;;
      armhf) DOWNLOAD_ARCH="armv7" ;;
      *) msg_error "Unsupported architecture: $ARCH"; exit 1 ;;
    esac
    
    curl -fsSL "https://github.com/donetick/donetick/releases/download/${RELEASE}/donetick_Linux_${DOWNLOAD_ARCH}.tar.gz" -o donetick.tar.gz
    tar -xzf donetick.tar.gz
    chmod +x donetick
    rm donetick.tar.gz
    
    # Restore configuration
    cp /opt/selfhosted.yaml.backup /opt/donetick/config/selfhosted.yaml
    rm /opt/selfhosted.yaml.backup
    
    echo "${RELEASE}" > "/opt/${APP}_version.txt"
    msg_ok "Updated ${APP} to ${RELEASE}"

    msg_info "Starting ${APP}"
    systemctl start donetick
    msg_ok "Started ${APP}"
    
    msg_ok "Updated Successfully"
  else
    msg_ok "No update required. ${APP} is already at ${RELEASE}."
  fi
  exit
}

start
build_container
description

msg_info "Installing Dependencies"
$STD apt-get install -y \
  curl \
  sudo \
  mc \
  gpg \
  ca-certificates \
  sqlite3
msg_ok "Installed Dependencies"

msg_info "Setting up ${APP} User"
useradd -r -s /bin/false -d /opt/donetick donetick
msg_ok "Created ${APP} User"

msg_info "Installing ${APP}"
mkdir -p /opt/donetick/{config,data}
cd /opt/donetick

# Get latest release
RELEASE=$(curl -fsSL https://api.github.com/repos/donetick/donetick/releases/latest | grep "tag_name" | awk '{print substr($2, 2, length($2)-3)}')

# Download the appropriate binary for the architecture
ARCH=$(dpkg --print-architecture)
case $ARCH in
  amd64) DOWNLOAD_ARCH="amd64" ;;
  arm64) DOWNLOAD_ARCH="arm64" ;;
  armhf) DOWNLOAD_ARCH="armv7" ;;
  *) msg_error "Unsupported architecture: $ARCH"; exit 1 ;;
esac

curl -fsSL "https://github.com/donetick/donetick/releases/download/${RELEASE}/donetick_Linux_${DOWNLOAD_ARCH}.tar.gz" -o donetick.tar.gz
tar -xzf donetick.tar.gz
chmod +x donetick
rm donetick.tar.gz

echo "${RELEASE}" > "/opt/${APP}_version.txt"
msg_ok "Installed ${APP} ${RELEASE}"

msg_info "Creating Configuration"
# Generate a secure JWT secret
JWT_SECRET=$(openssl rand -base64 32)

cat <<EOF > /opt/donetick/config/selfhosted.yaml
name: "selfhosted"
is_done_tick_dot_com: false
is_user_creation_disabled: false

telegram:
  token: ""
pushover:
  token: ""

database:
  type: "sqlite"
  migration: true

jwt:
  secret: "${JWT_SECRET}"
  session_time: 168h
  max_refresh: 168h

server:
  port: 2021
  read_timeout: 10s
  write_timeout: 10s
  rate_period: 60s
  rate_limit: 300
  cors_allow_origins:
    - "http://localhost:5173"
    - "http://localhost:7926"
    # the below are required for the android app to work
    - "https://localhost"
    - "capacitor://localhost"
  serve_frontend: true

logging:
  level: "info"
  encoding: "json"
  development: false

scheduler_jobs:
  due_job: 30m
  overdue_job: 3h
  pre_due_job: 3h

# Real-time configuration
realtime:
  enabled: true
  websocket_enabled: false
  sse_enabled: true
  heartbeat_interval: 60s
  connection_timeout: 120s
  max_connections: 1000
  max_connections_per_user: 5
  event_queue_size: 2048
  cleanup_interval: 2m
  stale_threshold: 5m
  enable_compression: true
  enable_stats: true
  allowed_origins:
    - "*"

email:
  host: ""
  port: ""
  key: ""
  email: ""
  appHost: ""

oauth2:
  client_id: ""
  client_secret: ""
  auth_url: ""
  token_url: ""
  user_info_url: ""
  redirect_url: ""
  name: ""
EOF

# Save configuration info for user
cat <<EOF > /root/donetick.creds
Donetick Configuration Details
=============================
Application: Donetick v${RELEASE}
Config File: /opt/donetick/config/selfhosted.yaml
Data Directory: /opt/donetick/data
Database: SQLite (/opt/donetick/data/donetick.db)
JWT Secret: ${JWT_SECRET}

Default Access:
- URL: http://$(hostname -I | awk '{print $1}'):2021
- First run will allow you to create an admin user

Android App Support:
- CORS origins are configured for Android app compatibility
- Supports both development and Capacitor app environments
- Use your server IP/domain in the Android app settings

Service Management:
- Start: systemctl start donetick
- Stop: systemctl stop donetick
- Status: systemctl status donetick
- Logs: journalctl -u donetick -f

Configuration:
Edit /opt/donetick/config/selfhosted.yaml to customize settings
such as notifications, OAuth, email, etc.
EOF

msg_ok "Created Configuration"

msg_info "Setting Permissions"
chown -R donetick:donetick /opt/donetick
chmod 755 /opt/donetick
chmod 644 /opt/donetick/config/selfhosted.yaml
chmod +x /opt/donetick/donetick
msg_ok "Set Permissions"

msg_info "Creating Systemd Service"
cat <<EOF > /etc/systemd/system/donetick.service
[Unit]
Description=Donetick Task Manager
After=network.target
Wants=network.target

[Service]
Type=simple
User=donetick
Group=donetick
WorkingDirectory=/opt/donetick
ExecStart=/opt/donetick/donetick
Environment=DT_ENV=selfhosted
Environment=DT_CONFIG_PATH=/opt/donetick/config/selfhosted.yaml
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/opt/donetick/data
CapabilityBoundingSet=
AmbientCapabilities=
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable donetick
msg_ok "Created Systemd Service"

msg_info "Starting ${APP}"
systemctl start donetick
msg_ok "Started ${APP}"

msg_info "Cleaning up"
apt-get autoremove -y
apt-get autoclean
msg_ok "Cleaned"

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:2021${CL}"
