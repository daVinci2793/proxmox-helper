#!/usr/bin/env bash
#
# Donetick PostgreSQL Migration Script
# Migrates existing SQLite installation to PostgreSQL
#

set -euo pipefail

# Script directory for relative paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common library first
if [[ -f "${SCRIPT_DIR}/lib/common.sh" ]]; then
  source "${SCRIPT_DIR}/lib/common.sh"
else
  echo "Error: Cannot find common library at ${SCRIPT_DIR}/lib/common.sh"
  exit 1
fi

# Load additional libraries
load_libraries() {
  source_library "database"
}

# Check if Donetick is installed
check_donetick_installed() {
  if ! is_donetick_installed; then
    msg_error "Donetick is not installed. Please install Donetick first before migrating."
  fi
  
  if [[ ! -f "${INSTALL_DIR}/donetick.db" ]]; then
    msg_error "SQLite database not found at ${INSTALL_DIR}/donetick.db"
  fi
}

# Show help
show_help() {
  cat << EOF
Donetick PostgreSQL Migration Tool

Usage: $0 [OPTIONS]

OPTIONS:
  -h, --help              Show this help message
  -i, --interactive       Interactive migration setup (default)
  --host HOST             PostgreSQL host (default: 192.168.86.31)
  --port PORT             PostgreSQL port (default: 5432)
  --database DATABASE     Database name (default: donetick)
  --username USERNAME     PostgreSQL username (default: postgres)
  --password PASSWORD     PostgreSQL password (prompted if not provided)
  --skip-backup          Skip SQLite database backup
  --dry-run              Show what would be done without executing

Examples:
  $0                                    # Interactive mode
  $0 --interactive                     # Interactive mode
  $0 --host 192.168.86.31 --database donetick --username postgres
  $0 --dry-run                         # Preview migration steps

This script will:
1. Stop the Donetick service
2. Backup the existing SQLite database
3. Export SQLite data to PostgreSQL-compatible SQL
4. Create the target PostgreSQL database if needed
5. Import the data to PostgreSQL
6. Update the Donetick configuration
7. Restart the service with the new configuration
8. Verify the migration was successful
EOF
}

# Dry run mode - show what would be done
dry_run_migration() {
  local host="$1"
  local port="$2"
  local database="$3"
  local username="$4"
  
  cat << EOF

=== DRY RUN: PostgreSQL Migration Plan ===

Target PostgreSQL Server: $username@$host:$port/$database

Migration Steps:
1. ✓ Check Donetick installation and SQLite database
2. ✓ Install PostgreSQL client tools (if needed)
3. ✓ Test connection to PostgreSQL server
4. ✓ Create database '$database' (if it doesn't exist)
5. ✓ Stop Donetick service
6. ✓ Backup SQLite database to: ${INSTALL_DIR}/backup/
7. ✓ Export SQLite data to PostgreSQL-compatible SQL
8. ✓ Import data to PostgreSQL database
9. ✓ Update configuration file: ${CONFIG_DIR}/selfhosted.yaml
10. ✓ Restart Donetick service
11. ✓ Verify migration success

Configuration Changes:
- Database type: sqlite → postgres
- Database file: ${INSTALL_DIR}/donetick.db → postgres://$username@$host:$port/$database

Files Modified:
- ${CONFIG_DIR}/selfhosted.yaml (backed up first)

Files Created:
- ${INSTALL_DIR}/backup/donetick_sqlite_backup_TIMESTAMP.db
- ${CONFIG_DIR}/selfhosted.yaml.backup.TIMESTAMP

Use --interactive or provide connection parameters to perform the actual migration.

EOF
}

main() {
  local interactive=true
  local dry_run=false
  local pg_host="192.168.86.31"
  local pg_port="5432"
  local pg_database="donetick"
  local pg_username="postgres"
  local pg_password=""
  local skip_backup="false"
  
  # Parse command line arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      -h|--help)
        show_help
        exit 0
        ;;
      -i|--interactive)
        interactive=true
        shift
        ;;
      --host)
        pg_host="$2"
        interactive=false
        shift 2
        ;;
      --port)
        pg_port="$2"
        interactive=false
        shift 2
        ;;
      --database)
        pg_database="$2"
        interactive=false
        shift 2
        ;;
      --username)
        pg_username="$2"
        interactive=false
        shift 2
        ;;
      --password)
        pg_password="$2"
        interactive=false
        shift 2
        ;;
      --skip-backup)
        skip_backup="true"
        shift
        ;;
      --dry-run)
        dry_run=true
        interactive=false
        shift
        ;;
      *)
        msg_error "Unknown option: $1"
        ;;
    esac
  done
  
  # Check root privileges
  check_root
  
  # Load libraries
  load_libraries
  
  # Check if Donetick is installed
  check_donetick_installed
  
  # Dry run mode
  if [[ "$dry_run" == "true" ]]; then
    dry_run_migration "$pg_host" "$pg_port" "$pg_database" "$pg_username"
    exit 0
  fi
  
  # Interactive mode
  if [[ "$interactive" == "true" ]]; then
    interactive_postgres_migration
    exit $?
  fi
  
  # Non-interactive mode - get password if not provided
  if [[ -z "$pg_password" ]]; then
    echo -n "PostgreSQL password for user '$pg_username': "
    read -s pg_password
    echo
  fi
  
  # Perform migration
  migrate_to_postgres "$pg_host" "$pg_port" "$pg_database" "$pg_username" "$pg_password" "$skip_backup"
}

# Only run main if script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
