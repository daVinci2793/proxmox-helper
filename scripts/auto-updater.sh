#!/usr/bin/env bash
#
# Donetick Automatic Updater
# This script is called by cron to check for and install updates
#

INSTALL_DIR="/opt/donetick"
VERSION_FILE="/opt/Donetick_version.txt"
LOG_FILE="/var/log/donetick-updater.log"
INSTALLER_URL="https://raw.githubusercontent.com/daVinci2793/proxmox-helper/main/donetick.sh"
TEMP_INSTALLER="/tmp/donetick-installer-latest.sh"

# Logging functions
log_msg() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $@" | tee -a "$LOG_FILE"
}

# Check if we're root
if [[ $EUID -ne 0 ]]; then
  log_msg "ERROR: Updater must run as root"
  exit 1
fi

# Self-update check: Download latest installer and compare
log_msg "INFO: Checking for updater script updates..."
if curl -fsSL "$INSTALLER_URL" -o "$TEMP_INSTALLER" 2>/dev/null; then
  # Compare current script with downloaded version
  current_checksum=$(sha256sum "$0" 2>/dev/null | cut -d' ' -f1)
  new_checksum=$(sha256sum "$TEMP_INSTALLER" 2>/dev/null | cut -d' ' -f1)
  
  if [[ "$current_checksum" != "$new_checksum" ]]; then
    log_msg "INFO: Updater script has been updated, replacing and re-executing..."
    chmod +x "$TEMP_INSTALLER"
    # Replace self and re-execute
    cp "$TEMP_INSTALLER" "$0"
    rm -f "$TEMP_INSTALLER"
    exec "$0" "$@"
  else
    log_msg "INFO: Updater script is current"
    rm -f "$TEMP_INSTALLER"
  fi
else
  log_msg "WARNING: Could not download latest installer for self-update check"
  rm -f "$TEMP_INSTALLER"
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

latest_tag=$(echo "$latest_info" | grep "tag_name" | awk '{print substr($2, 2, length($2)-3)}')
# Keep the original tag for URL, but clean version for comparison
latest_version=${latest_tag#v}

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

# Check for breaking changes
log_msg "INFO: Checking for breaking changes in v${latest_version}..."
release_notes=$(curl -fsSL "https://api.github.com/repos/donetick/donetick/releases/tags/v${latest_version}" 2>/dev/null)
if [[ $? -eq 0 ]] && [[ -n "$release_notes" ]]; then
  body=$(echo "$release_notes" | grep -o '"body":"[^"]*"' | sed 's/"body":"//;s/"$//' | sed 's/\\n/\n/g')
  
  # Check for breaking change indicators
  if echo "$body" | grep -qi -E "(breaking|migration|config.change|incompatible|deprecated|database.migration)"; then
    log_msg "WARNING: Potential breaking changes detected in v${latest_version}"
    log_msg "WARNING: Update postponed - manual review required"
    log_msg "WARNING: Configuration backup preserved for manual review"
    log_msg "WARNING: See: https://github.com/donetick/donetick/releases/tag/v${latest_version}"
    exit 1
  fi
fi

log_msg "INFO: Starting automatic update..."

# Download and run the installer script
if curl -fsSL "$INSTALLER_URL" | bash >> "$LOG_FILE" 2>&1; then
  log_msg "SUCCESS: Donetick updated to version $latest_version"
  
  # Ensure proper ownership after update
  if [[ -d "$INSTALL_DIR" ]]; then
    chown -R donetick:donetick "$INSTALL_DIR" 2>/dev/null || true
    log_msg "INFO: File ownership updated"
  fi
  
  # Set ownership on database if it exists
  if [[ -f "$INSTALL_DIR/donetick.db" ]]; then
    chown donetick:donetick "$INSTALL_DIR/donetick.db" 2>/dev/null || true
    log_msg "INFO: Database file ownership updated"
  fi
else
  log_msg "ERROR: Update failed, check logs for details"
  exit 1
fi
