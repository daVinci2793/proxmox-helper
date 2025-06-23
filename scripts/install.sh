#!/usr/bin/env bash
#
# Donetick Installation Script
# Handles fresh installation of Donetick
#

install_donetick() {
  local force_install="${1:-false}"
  
  msg_info "Beginning Donetick installation..."
  
  # Step 1: Install Dependencies
  install_dependencies
  
  # Step 2: Create Application User
  create_service_user
  
  # Step 3: Download and Install Donetick
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
  
  msg_info "Downloading Donetick v${latest_version} for ${arch}..."
  msg_info "Download URL: ${download_url}"
  
  mkdir -p "${INSTALL_DIR}"
  download_file "$download_url" "${INSTALL_DIR}/donetick.tar.gz" "Donetick binary"
  
  msg_info "Extracting archive..."
  tar -xzf "${INSTALL_DIR}/donetick.tar.gz" -C "${INSTALL_DIR}"
  rm "${INSTALL_DIR}/donetick.tar.gz"
  echo "${latest_version}" > "${VERSION_FILE}"
  
  msg_ok "Donetick v${latest_version} installed successfully."
  
  # Step 4: Handle Configuration
  handle_configuration "false" "$force_install"
  
  # Step 5: Set Permissions
  set_file_permissions
  
  # Step 6: Create Systemd Service
  create_systemd_service
  
  # Step 7: Start and Enable Service
  start_and_enable_service
  
  # Step 8: Create Credentials File
  create_credentials_file "$latest_version" "false"
  
  msg_ok "Donetick installation complete!"
}
