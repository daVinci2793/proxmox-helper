#!/usr/bin/env bash
#
# Donetick Update Script
# Handles updates of existing Donetick installation
#

update_donetick() {
  local force_install="${1:-false}"
  
  local current_version=$(get_current_version)
  msg_info "Beginning Donetick update from version ${current_version}..."
  
  # Check for breaking changes before proceeding
  local latest_version=$(get_latest_version)
  if ! check_breaking_changes "$latest_version"; then
    msg_warn "Breaking changes detected. Please review release notes before updating."
    msg_warn "To force update anyway, use the --force flag"
    if [[ "$force_install" != "true" ]]; then
      exit 1
    fi
  fi
  
  # Backup configuration
  backup_config
  
  # Step 1: Stop existing service
  stop_service_if_running
  
  # Step 2: Download and Install new version
  msg_info "Fetching latest release information from GitHub..."
  local latest_tag=$(get_latest_tag)
  local latest_version=${latest_tag#v}
  
  msg_info "Latest tag from GitHub: '${latest_tag}'"
  msg_info "Parsed version: ${latest_version}"
  
  if [[ -z "$latest_version" ]]; then
    msg_error "Could not determine latest Donetick version. Aborting."
  fi
  
  local arch=$(get_system_architecture)
  local download_url=$(get_download_url "$latest_tag" "$arch")
  
  msg_info "Updating Donetick to v${latest_version} for ${arch}..."
  msg_info "Download URL: ${download_url}"
  
  download_file "$download_url" "${INSTALL_DIR}/donetick.tar.gz" "Donetick binary"
  
  msg_info "Extracting archive..."
  tar -xzf "${INSTALL_DIR}/donetick.tar.gz" -C "${INSTALL_DIR}"
  rm "${INSTALL_DIR}/donetick.tar.gz"
  echo "${latest_version}" > "${VERSION_FILE}"
  
  msg_ok "Donetick updated to v${latest_version} successfully."
  
  # Step 3: Handle Configuration (restore backup)
  handle_configuration "true" "$force_install"
  
  # Step 4: Set Permissions
  set_file_permissions
  
  # Step 5: Update Systemd Service (in case template changed)
  create_systemd_service
  
  # Step 6: Start Service
  start_and_enable_service
  
  # Step 7: Update Credentials File
  create_credentials_file "$latest_version" "true"
  
  msg_ok "Donetick update complete!"
}
