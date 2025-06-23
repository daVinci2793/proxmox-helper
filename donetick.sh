#!/usr/bin/env bash
#
# Donetick Main Installer & Updater
#
# Description: Modular installer/updater for Donetick, an open-source task manager.
# Features: 
#   - Fresh installation
#   - Update existing installation
#   - Automatic periodic updates via cron
#   - Modular architecture with separate libraries
# Author: daVinci
# License: MIT
# Repository: https://github.com/donetick/donetick
#

set -euo pipefail

# Script directory for relative paths
# Determine script directory - handle both file execution and curl piping
if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
    # When running via curl, use current directory or create temp directory
    SCRIPT_DIR="$(pwd)"
fi

# Source common library first
if [[ -f "${SCRIPT_DIR}/lib/common.sh" ]]; then
  source "${SCRIPT_DIR}/lib/common.sh"
else
  # Fallback: try to download common library
  echo "Downloading common library..."
  BASE_URL="${DONETICK_BASE_URL:-https://raw.githubusercontent.com/daVinci2793/proxmox-helper/main}"
  TEMP_COMMON="/tmp/donetick-common.sh"
  if curl -fsSL "${BASE_URL}/lib/common.sh" -o "$TEMP_COMMON" 2>/dev/null; then
    source "$TEMP_COMMON"
    rm -f "$TEMP_COMMON"
  else
    echo "ERROR: Could not load common library"
    exit 1
  fi
fi

# Load additional libraries
load_libraries() {
  source_library "github"
  source_library "system"
  source_library "config"
  source_library "service"
}

# Source operation scripts
source_operation_script() {
  local script_name="$1"
  local script_path="scripts/${script_name}.sh"
  local remote_url="${BASE_URL}/${script_path}"
  
  # Try local file first
  if [[ -f "${SCRIPT_DIR}/${script_path}" ]]; then
    source "${SCRIPT_DIR}/${script_path}"
  else
    # Download and source from remote
    local temp_file="/tmp/donetick-${script_name}.sh"
    if download_file "$remote_url" "$temp_file" "${script_name} script"; then
      source "$temp_file"
      rm -f "$temp_file"
    else
      msg_error "Could not load required script: $script_name"
    fi
  fi
}

# --- Main Execution Functions ---
run_pre_checks() {
  msg_info "Performing pre-run checks..."
  check_root
  check_systemd
  msg_ok "Pre-run checks passed."
}

determine_operation() {
  if is_donetick_installed; then
    echo "update"
  else
    echo "install"
  fi
}

run_install() {
  local force_install="$1"
  source_operation_script "install"
  install_donetick "$force_install"
}

run_update() {
  local force_install="$1"
  source_operation_script "update"
  update_donetick "$force_install"
}

run_postgres_migration() {
  msg_info "Starting PostgreSQL migration..."
  source_library "database"
  interactive_postgres_migration
}

show_help() {
  cat << EOF
Donetick Installer & Updater (Modular Version)

Usage: $0 [OPTIONS]

OPTIONS:
  -h, --help              Show this help message
  -c, --check             Check for updates without installing
  -f, --force             Force installation/update even if up to date
  --setup-auto-updates    Setup automatic updates (runs with install by default)
  --disable-auto-updates  Disable automatic updates
  --migrate-to-postgres   Migrate existing SQLite database to PostgreSQL

Examples:
  $0                      Install or update Donetick
  $0 --check             Check if updates are available
  $0 --force             Force reinstall current version
  $0 --migrate-to-postgres  Migrate SQLite database to PostgreSQL

Architecture:
  This script uses a modular architecture with separate libraries:
  - lib/common.sh         Common utilities and configuration
  - lib/github.sh         GitHub API interactions
  - lib/system.sh         System operations
  - lib/config.sh         Configuration management
  - lib/service.sh        Service management
  - lib/database.sh       Database migration operations
  - scripts/install.sh    Installation logic
  - scripts/update.sh     Update logic
EOF
}

main() {
  local check_only=false
  local force_install=false
  local setup_auto=true
  local migrate_postgres=false
  local operation=""
  
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
      --migrate-to-postgres)
        migrate_postgres=true
        shift
        ;;
      *)
        msg_error "Unknown option: $1. Use --help for usage information."
        ;;
    esac
  done
  
  # Load all required libraries
  load_libraries
  
  # Run pre-checks
  run_pre_checks
  
  # Handle PostgreSQL migration mode
  if [[ "$migrate_postgres" == "true" ]]; then
    run_postgres_migration
    exit $?
  fi
  
  # Handle check-only mode
  if [[ "$check_only" == "true" ]]; then
    check_for_updates
    exit $?
  fi
  
  # Determine what operation to perform
  operation=$(determine_operation)
  
  # Check for updates unless forced
  if [[ "$force_install" == "false" ]] && [[ "$operation" == "update" ]]; then
    if ! check_for_updates; then
      msg_info "No action needed."
      exit 0
    fi
  elif [[ "$force_install" == "true" ]]; then
    msg_info "Forcing installation/update..."
  fi
  
  # Perform the operation
  case $operation in
    install)
      run_install "$force_install"
      ;;
    update)
      run_update "$force_install"
      ;;
    *)
      msg_error "Unknown operation: $operation"
      ;;
  esac
  
  # Setup automatic updates if requested
  if [[ "$setup_auto" == "true" ]]; then
    setup_automatic_updates
  fi

  # Show completion message
  echo
  local current_version=$(get_current_version)
  if [[ "$operation" == "install" ]]; then
    msg_ok "Donetick installation complete!"
  else
    msg_ok "Donetick update complete!"
  fi
  
  local ip_addr=$(hostname -I | awk '{print $1}')
  msg_info "You can now access Donetick at http://${ip_addr}:2021"
  msg_info "On first access, you will be prompted to create an admin account."
  
  if [[ "$setup_auto" == "true" ]]; then
    msg_info "Automatic updates are enabled and will run daily at 3:00 AM."
    msg_info "Update logs: /var/log/donetick-updater.log"
    msg_info "To check for updates manually: ${UPDATER_SCRIPT}"
  fi
  echo
}

# Only run main if script is executed directly (not sourced)
# Handle both file execution and curl piping contexts
if [[ -z "${BASH_SOURCE[0]:-}" ]] || [[ "${BASH_SOURCE[0]:-}" == "${0}" ]]; then
  main "$@"
fi
