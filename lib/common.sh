#!/usr/bin/env bash
#
# Donetick Common Library
# Shared utilities and configuration
#

# --- Configuration Constants ---
readonly APP_NAME="Donetick"
readonly INSTALL_DIR="/opt/donetick"
readonly CONFIG_DIR="${INSTALL_DIR}/config"
readonly SERVICE_USER="donetick"
readonly SERVICE_FILE="/etc/systemd/system/donetick.service"
readonly VERSION_FILE="/opt/${APP_NAME}_version.txt"
readonly UPDATER_SCRIPT="/usr/local/bin/donetick-updater"
readonly CRON_FILE="/etc/cron.d/donetick-updates"

# Base URL for remote resources (can be overridden)
readonly BASE_URL="${DONETICK_BASE_URL:-https://raw.githubusercontent.com/daVinci2793/proxmox-helper/main}"

# --- Colors for Logging ---
readonly YW=$(echo -e '\033[33m')
readonly BL=$(echo -e '\033[36m')
readonly RD=$(echo -e '\033[01;31m')
readonly GN=$(echo -e '\033[1;92m')
readonly CL=$(echo -e '\033[0m')

# --- Logging Functions ---
msg_info() { echo -e "${BL}[INFO]${CL} $@"; }
msg_ok() { echo -e "${GN}[OK]${CL} $@"; }
msg_warn() { echo -e "${YW}[WARN]${CL} $@"; }
msg_error() { echo -e "${RD}[ERROR]${CL} $@"; exit 1; }

# --- Utility Functions ---
get_current_version() {
  if [[ -f "${VERSION_FILE}" ]]; then
    cat "${VERSION_FILE}"
  else
    echo "none"
  fi
}

version_compare() {
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

is_donetick_installed() {
  local current_version=$(get_current_version)
  [[ "$current_version" != "none" ]] && [[ -d "${INSTALL_DIR}" ]] && [[ -f "${INSTALL_DIR}/donetick" ]]
}

check_root() {
  if [[ $EUID -ne 0 ]]; then
    msg_error "This script must be run as root. Please use 'sudo'."
  fi
}

check_systemd() {
  if ! command -v systemctl >/dev/null 2>&1; then
    msg_error "This script requires systemd, which was not found on this system."
  fi
}

download_file() {
  local url="$1"
  local output="$2"
  local description="${3:-file}"
  
  msg_info "Downloading ${description}..."
  if curl -fsSL "$url" -o "$output"; then
    msg_ok "${description} downloaded successfully"
    return 0
  else
    msg_error "Failed to download ${description} from $url"
    return 1
  fi
}

# Source a library file (download if not available locally)
source_library() {
  local lib_name="$1"
  local lib_path="lib/${lib_name}.sh"
  local remote_url="${BASE_URL}/${lib_path}"
  
  # Try local file first
  if [[ -f "$lib_path" ]]; then
    source "$lib_path"
  else
    # Download and source from remote
    local temp_file="/tmp/donetick-${lib_name}.sh"
    if download_file "$remote_url" "$temp_file" "${lib_name} library"; then
      source "$temp_file"
      rm -f "$temp_file"
    else
      msg_error "Could not load required library: $lib_name"
    fi
  fi
}
