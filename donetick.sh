#!/usr/bin/env bash
#
# Donetick Standalone Installer & Updater
#
# Description: Installs/updates Donetick, an open-source task manager, on a Debian-based system.
# Features: 
#   - Fresh installation
#   - Update existing installation
#   - Automatic periodic updates via cron
# Author: daVinci
# License: MIT
# Repository: https://github.com/donetick/donetick
#

# --- Configuration ---
APP_NAME="Donetick"
INSTALL_DIR="/opt/donetick"
CONFIG_DIR="${INSTALL_DIR}/config"
DATA_DIR="${INSTALL_DIR}/data"
SERVICE_USER="donetick"
SERVICE_FILE="/etc/systemd/system/donetick.service"
VERSION_FILE="/opt/${APP_NAME}_version.txt"
UPDATER_SCRIPT="/usr/local/bin/donetick-updater"
CRON_FILE="/etc/cron.d/donetick-updates"

# --- Colors for Logging ---
YW=$(echo -e '\033[33m')
BL=$(echo -e '\033[36m')
RD=$(echo -e '\033[01;31m')
GN=$(echo -e '\033[1;92m')
CL=$(echo -e '\033[0m')

# --- Logging Functions ---
msg_info() { echo -e "${BL}[INFO]${CL} $@"; }
msg_ok() { echo -e "${GN}[OK]${CL} $@"; }
msg_warn() { echo -e "${YW}[WARN]${CL} $@"; }
msg_error() { echo -e "${RD}[ERROR]${CL} $@"; exit 1; }

# --- Utility Functions ---
function get_current_version() {
  if [[ -f "${VERSION_FILE}" ]]; then
    cat "${VERSION_FILE}"
  else
    echo "none"
  fi
}

function get_latest_version() {
  local release_info=$(curl -fsSL "https://api.github.com/repos/donetick/donetick/releases/latest" 2>/dev/null)
  if [[ $? -eq 0 ]] && [[ -n "$release_info" ]]; then
    local version=$(echo "$release_info" | grep "tag_name" | awk '{print substr($2, 2, length($2)-3)}')
    # Remove any leading 'v' from version if it exists
    echo "${version#v}"
  else
    echo ""
  fi
}

function version_compare() {
  # Returns: 0 if equal, 1 if v1 > v2, 2 if v1 < v2
  local v1="$1"
  local v2="$2"
  
  if [[ "$v1" == "$v2" ]]; then
    return 0
  fi
  
  # Use sort -V for version comparison
  local sorted=$(printf '%s\n%s\n' "$v1" "$v2" | sort -V)
  local first=$(echo "$sorted" | head -n1)
  
  if [[ "$first" == "$v1" ]]; then
    return 2  # v1 < v2
  else
    return 1  # v1 > v2
  fi
}

function check_for_updates() {
  msg_info "Checking for updates..."
  
  local current_version=$(get_current_version)
  local latest_version=$(get_latest_version)
  
  if [[ -z "$latest_version" ]]; then
    msg_warn "Could not fetch latest version information from GitHub."
    return 1
  fi
  
  msg_info "Current version: ${current_version}"
  msg_info "Latest version:  ${latest_version}"
  
  if [[ "$current_version" == "none" ]]; then
    msg_info "No existing installation found. Will perform fresh installation."
    return 0
  fi
  
  version_compare "$current_version" "$latest_version"
  local result=$?
  
  case $result in
    0)
      msg_ok "Already running the latest version (${current_version})"
      return 1
      ;;
    1)
      msg_warn "Current version (${current_version}) is newer than latest release (${latest_version})"
      return 1
      ;;
    2)
      msg_info "Update available: ${current_version} → ${latest_version}"
      return 0
      ;;
  esac
}

function backup_config() {
  local backup_file="${CONFIG_DIR}/selfhosted.yaml.backup.$(date +%Y%m%d_%H%M%S)"
  if [[ -f "${CONFIG_DIR}/selfhosted.yaml" ]]; then
    msg_info "Backing up existing configuration..."
    cp "${CONFIG_DIR}/selfhosted.yaml" "$backup_file"
    msg_ok "Configuration backed up to: $backup_file"
  fi
}

function create_updater_script() {
  msg_info "Creating automatic updater script..."
  
  cat <<'EOF' > "${UPDATER_SCRIPT}"
#!/usr/bin/env bash
#
# Donetick Automatic Updater
# This script is called by cron to check for and install updates
#

INSTALL_DIR="/opt/donetick"
VERSION_FILE="/opt/Donetick_version.txt"
LOG_FILE="/var/log/donetick-updater.log"

# Logging functions
log_msg() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $@" | tee -a "$LOG_FILE"
}

# Check if we're root
if [[ $EUID -ne 0 ]]; then
  log_msg "ERROR: Updater must run as root"
  exit 1
fi

# Check if Donetick is installed
if [[ ! -f "$VERSION_FILE" ]] || [[ ! -d "$INSTALL_DIR" ]]; then
  log_msg "INFO: Donetick not found, skipping update check"
  exit 0
fi

# Get current and latest versions
current_version=$(cat "$VERSION_FILE" 2>/dev/null || echo "unknown")
latest_info=$(curl -fsSL "https://api.github.com/repos/donetick/donetick/releases/latest" 2>/dev/null)

if [[ $? -ne 0 ]] || [[ -z "$latest_info" ]]; then
  log_msg "WARNING: Could not fetch latest version from GitHub"
  exit 1
fi

latest_version=$(echo "$latest_info" | grep "tag_name" | awk '{print substr($2, 2, length($2)-3)}')
# Remove any leading 'v' from version if it exists
latest_version=${latest_version#v}

if [[ -z "$latest_version" ]]; then
  log_msg "WARNING: Could not parse latest version"
  exit 1
fi

# Version comparison
if [[ "$current_version" == "$latest_version" ]]; then
  log_msg "INFO: Already running latest version ($current_version)"
  exit 0
fi

# Use sort for version comparison
sorted=$(printf '%s\n%s\n' "$current_version" "$latest_version" | sort -V)
first=$(echo "$sorted" | head -n1)

if [[ "$first" != "$current_version" ]]; then
  log_msg "INFO: Current version ($current_version) is newer than release ($latest_version)"
  exit 0
fi

# Update available
log_msg "INFO: Update available: $current_version → $latest_version"
log_msg "INFO: Starting automatic update..."

# Download and run the installer script
if curl -fsSL "https://raw.githubusercontent.com/daVinci2793/proxmox-helper/main/donetick.sh" | bash >> "$LOG_FILE" 2>&1; then
  log_msg "SUCCESS: Donetick updated to version $latest_version"
else
  log_msg "ERROR: Update failed, check logs for details"
  exit 1
fi
EOF

  chmod +x "${UPDATER_SCRIPT}"
  msg_ok "Updater script created at ${UPDATER_SCRIPT}"
}

function setup_automatic_updates() {
  msg_info "Setting up automatic updates..."
  
  # Create the updater script
  create_updater_script
  
  # Create cron job (runs daily at 3 AM)
  cat <<EOF > "${CRON_FILE}"
# Donetick Automatic Updates
# Runs daily at 3:00 AM to check for and install updates
0 3 * * * root ${UPDATER_SCRIPT} >/dev/null 2>&1
EOF
  
  # Ensure cron service is enabled
  if command -v systemctl >/dev/null 2>&1; then
    systemctl enable cron >/dev/null 2>&1 || systemctl enable cronie >/dev/null 2>&1 || true
  fi
  
  msg_ok "Automatic updates configured (daily at 3:00 AM)"
  msg_info "Logs will be written to: /var/log/donetick-updater.log"
}

# --- Pre-run Checks ---
function pre_run_checks() {
  msg_info "Performing pre-run checks..."
  # Check for root privileges
  if [[ $EUID -ne 0 ]]; then
    msg_error "This script must be run as root. Please use 'sudo'."
  fi

  # Check for systemd
  if ! command -v systemctl >/dev/null 2>&1; then
    msg_error "This script requires systemd, which was not found on this system."
  fi
  msg_ok "Pre-run checks passed."
}

# --- Installation Steps ---
function install_donetick() {
  set -e # Exit immediately if a command exits with a non-zero status.

  local current_version=$(get_current_version)
  local is_update=false
  
  if [[ "$current_version" != "none" ]]; then
    is_update=true
    msg_info "Beginning Donetick update from version ${current_version}..."
    backup_config
  else
    msg_info "Beginning Donetick installation..."
  fi

  # Step 1: Install Dependencies
  msg_info "Updating package lists and installing dependencies..."
  apt-get update >/dev/null
  apt-get install -y curl sqlite3 gpg ca-certificates openssl cron >/dev/null
  msg_ok "Dependencies installed successfully."

  # Step 2: Create Application User
  msg_info "Creating system user '${SERVICE_USER}'..."
  if id "${SERVICE_USER}" &>/dev/null; then
    msg_warn "User '${SERVICE_USER}' already exists. Skipping creation."
  else
    useradd -r -s /bin/false -d "${INSTALL_DIR}" "${SERVICE_USER}"
    msg_ok "System user '${SERVICE_USER}' created."
  fi

  # Step 3: Stop existing service if updating
  if systemctl is-active --quiet donetick; then
    msg_info "Donetick is running. Stopping service for update..."
    systemctl stop donetick
    msg_ok "Service stopped."
  fi

  # Step 4: Download and Install Donetick
  msg_info "Fetching latest release information from GitHub..."
  RELEASE_INFO=$(curl -fsSL "https://api.github.com/repos/donetick/donetick/releases/latest")
  LATEST_VERSION=$(echo "$RELEASE_INFO" | grep "tag_name" | awk '{print substr($2, 2, length($2)-3)}')
  
  # Remove any leading 'v' from version if it exists
  LATEST_VERSION=${LATEST_VERSION#v}
  
  msg_info "Parsed version: ${LATEST_VERSION}"
  
  if [ -z "$LATEST_VERSION" ]; then
    msg_error "Could not determine latest Donetick version. Aborting."
  fi

  ARCH=$(dpkg --print-architecture)
  DOWNLOAD_ARCH=""
  case $ARCH in
    amd64) DOWNLOAD_ARCH="x86_64" ;;
    arm64) DOWNLOAD_ARCH="arm64" ;;
    armhf) DOWNLOAD_ARCH="armv7" ;;
    *) msg_error "Unsupported architecture: ${ARCH}. Cannot continue." ;;
  esac

  DOWNLOAD_URL="https://github.com/donetick/donetick/releases/download/${LATEST_VERSION}/donetick_Linux_${DOWNLOAD_ARCH}.tar.gz"

  if [[ "$is_update" == "true" ]]; then
    msg_info "Updating Donetick to v${LATEST_VERSION} for ${ARCH}..."
  else
    msg_info "Downloading Donetick v${LATEST_VERSION} for ${ARCH}..."
  fi
  
  msg_info "Download URL: ${DOWNLOAD_URL}"
  
  mkdir -p "${INSTALL_DIR}"
  curl -fsSL "${DOWNLOAD_URL}" -o "${INSTALL_DIR}/donetick.tar.gz"
  
  msg_info "Extracting archive..."
  tar -xzf "${INSTALL_DIR}/donetick.tar.gz" -C "${INSTALL_DIR}"
  rm "${INSTALL_DIR}/donetick.tar.gz"
  echo "${LATEST_VERSION}" > "${VERSION_FILE}"
  
  if [[ "$is_update" == "true" ]]; then
    msg_ok "Donetick updated to v${LATEST_VERSION} successfully."
  else
    msg_ok "Donetick v${LATEST_VERSION} installed successfully."
  fi

  # Step 5: Create Configuration (only if not updating)
  if [[ "$is_update" == "false" ]]; then
    msg_info "Creating configuration file..."
    mkdir -p "${CONFIG_DIR}" "${DATA_DIR}"
    JWT_SECRET=$(openssl rand -base64 32)

    cat <<EOF > "${CONFIG_DIR}/selfhosted.yaml"
# Donetick Self-Hosted Configuration
# Generated by installer on $(date)
# For more options, see: https://github.com/donetick/donetick/blob/main/config/selfhosted.yaml.dist

name: "selfhosted"
is_done_tick_dot_com: false
is_user_creation_disabled: false

# Database Configuration
database:
  type: "sqlite"
  migration: true

# JWT Authentication
jwt:
  secret: "${JWT_SECRET}"
  session_time: 168h
  max_refresh: 168h

# Server Configuration
server:
  port: 2021
  read_timeout: 10s
  write_timeout: 10s
  rate_period: 60s
  rate_limit: 300
  cors_allow_origins:
    - "http://localhost:5173"
    - "http://localhost:7926"
    - "https://localhost"
    - "capacitor://localhost"
  serve_frontend: true

# Logging Configuration
logging:
  level: "info"
  encoding: "json"
  development: false

# Scheduler Jobs
scheduler_jobs:
  due_job: 30m
  overdue_job: 3h
  pre_due_job: 3h

# Email Configuration
email:
  host: 
  port: 
  key: 
  email:  
  appHost:  

# OAuth2 Configuration
oauth2:
  client_id: 
  client_secret: 
  auth_url: 
  token_url: 
  user_info_url: 
  redirect_url: 
  name:

# Real-time Configuration
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
EOF
    msg_ok "Default configuration created at ${CONFIG_DIR}/selfhosted.yaml"
  else
    msg_info "Preserving existing configuration file..."
    mkdir -p "${CONFIG_DIR}" "${DATA_DIR}"
  fi

  # Step 6: Set Permissions
  msg_info "Setting file permissions..."
  chown -R "${SERVICE_USER}":"${SERVICE_USER}" "${INSTALL_DIR}"
  chmod 750 "${INSTALL_DIR}"
  if [[ -f "${CONFIG_DIR}/selfhosted.yaml" ]]; then
    chmod 640 "${CONFIG_DIR}/selfhosted.yaml"
  fi
  chmod +x "${INSTALL_DIR}/donetick"
  msg_ok "Permissions set."

  # Step 7: Create Systemd Service
  msg_info "Creating systemd service..."
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
ReadWritePaths=${DATA_DIR}
CapabilityBoundingSet=
AmbientCapabilities=
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true

[Install]
WantedBy=multi-user.target
EOF
  msg_ok "Systemd service file created at ${SERVICE_FILE}"

  # Step 8: Start and Enable Service
  msg_info "Reloading systemd, enabling and starting Donetick service..."
  systemctl daemon-reload
  systemctl enable --now donetick
  msg_ok "Donetick service started and enabled on boot."

  # Step 9: Create Credentials File
  msg_info "Creating credentials and information file..."
  IP_ADDR=$(hostname -I | awk '{print $1}')
  
  # Get JWT secret from config if it exists
  local jwt_secret="Check config file"
  if [[ -f "${CONFIG_DIR}/selfhosted.yaml" ]] && [[ "$is_update" == "false" ]]; then
    jwt_secret="${JWT_SECRET}"
  fi
  
  cat <<EOF > /root/donetick.creds
Donetick Installation Details
=============================
Version:      ${LATEST_VERSION}
Access URL:   http://${IP_ADDR}:2021
Install Dir:  ${INSTALL_DIR}
Config File:  ${CONFIG_DIR}/selfhosted.yaml
Data Dir:     ${DATA_DIR}
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
  msg_ok "Installation details saved to /root/donetick.creds"
}

# --- Main Execution ---
function show_help() {
  cat << EOF
Donetick Installer & Updater

Usage: $0 [OPTIONS]

OPTIONS:
  -h, --help              Show this help message
  -c, --check             Check for updates without installing
  -f, --force             Force installation/update even if up to date
  --setup-auto-updates    Setup automatic updates (runs with install by default)
  --disable-auto-updates  Disable automatic updates

Examples:
  $0                      Install or update Donetick
  $0 --check             Check if updates are available
  $0 --force             Force reinstall current version
EOF
}

function main() {
  local check_only=false
  local force_install=false
  local setup_auto=true
  
  # Parse command line arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      -h|--help)
        show_help
        exit 0
        ;;
      -c|--check)
        check_only=true
        shift
        ;;
      -f|--force)
        force_install=true
        shift
        ;;
      --setup-auto-updates)
        setup_auto=true
        shift
        ;;
      --disable-auto-updates)
        setup_auto=false
        shift
        ;;
      *)
        msg_error "Unknown option: $1. Use --help for usage information."
        ;;
    esac
  done
  
  pre_run_checks
  
  if [[ "$check_only" == "true" ]]; then
    check_for_updates
    exit $?
  fi
  
  # Check for updates unless forced
  if [[ "$force_install" == "false" ]]; then
    if ! check_for_updates; then
      msg_info "No action needed."
      exit 0
    fi
  else
    msg_info "Forcing installation/update..."
  fi
  
  install_donetick
  
  # Setup automatic updates if requested and not in update-only mode
  if [[ "$setup_auto" == "true" ]]; then
    setup_automatic_updates
  fi

  echo
  if [[ "$(get_current_version)" != "none" ]]; then
    msg_ok "Donetick installation/update complete!"
  else
    msg_ok "Donetick installation complete!"
  fi
  msg_info "You can now access Donetick at http://$(hostname -I | awk '{print $1}'):2021"
  msg_info "On first access, you will be prompted to create an admin account."
  if [[ "$setup_auto" == "true" ]]; then
    msg_info "Automatic updates are enabled and will run daily at 3:00 AM."
    msg_info "Update logs: /var/log/donetick-updater.log"
    msg_info "To check for updates manually: ${UPDATER_SCRIPT}"
  fi
  echo
}

main "$@"
