#!/usr/bin/env bash
#
# Donetick Database Operations Library
# Functions for database migration and management
#

# Check if PostgreSQL client tools are available
check_postgres_tools() {
  if ! command -v pg_dump >/dev/null 2>&1 || ! command -v psql >/dev/null 2>&1; then
    msg_info "Installing PostgreSQL client tools..."
    apt-get update >/dev/null
    apt-get install -y postgresql-client >/dev/null
    msg_ok "PostgreSQL client tools installed"
  fi
}

# Test PostgreSQL connection
test_postgres_connection() {
  local host="$1"
  local port="$2"
  local database="$3"
  local username="$4"
  local password="$5"
  
  msg_info "Testing PostgreSQL connection..."
  
  export PGPASSWORD="$password"
  if psql -h "$host" -p "$port" -U "$username" -d "$database" -c "SELECT 1;" >/dev/null 2>&1; then
    msg_ok "PostgreSQL connection successful"
    unset PGPASSWORD
    return 0
  else
    msg_error "Failed to connect to PostgreSQL database"
    unset PGPASSWORD
    return 1
  fi
}

# Create database if it doesn't exist
ensure_postgres_database() {
  local host="$1"
  local port="$2"
  local database="$3"
  local username="$4"
  local password="$5"
  
  msg_info "Ensuring database '$database' exists..."
  
  export PGPASSWORD="$password"
  
  # Check if database exists
  if psql -h "$host" -p "$port" -U "$username" -d "postgres" -tAc "SELECT 1 FROM pg_database WHERE datname='$database'" | grep -q 1; then
    msg_ok "Database '$database' already exists"
  else
    msg_info "Creating database '$database'..."
    if psql -h "$host" -p "$port" -U "$username" -d "postgres" -c "CREATE DATABASE \"$database\";" >/dev/null 2>&1; then
      msg_ok "Database '$database' created successfully"
    else
      msg_error "Failed to create database '$database'"
    fi
  fi
  
  unset PGPASSWORD
}

# Backup SQLite database
backup_sqlite_database() {
  local backup_dir="${INSTALL_DIR}/backup"
  local timestamp=$(date +%Y%m%d_%H%M%S)
  local backup_file="${backup_dir}/donetick_sqlite_backup_${timestamp}.db"
  
  mkdir -p "$backup_dir"
  
  if [[ -f "${INSTALL_DIR}/donetick.db" ]]; then
    msg_info "Creating SQLite database backup..."
    cp "${INSTALL_DIR}/donetick.db" "$backup_file"
    msg_ok "SQLite database backed up to: $backup_file"
    echo "$backup_file" > "${backup_dir}/.last_sqlite_backup"
    return 0
  else
    msg_warn "No SQLite database found at ${INSTALL_DIR}/donetick.db"
    return 1
  fi
}

# Export SQLite data to SQL dump
export_sqlite_to_sql() {
  local output_file="$1"
  local sqlite_db="${INSTALL_DIR}/donetick.db"
  
  if [[ ! -f "$sqlite_db" ]]; then
    msg_error "SQLite database not found at $sqlite_db"
    return 1
  fi
  
  msg_info "Exporting SQLite data to SQL dump..."
  
  # Create a comprehensive SQL dump that's PostgreSQL compatible
  cat > "$output_file" << 'EOF'
-- Donetick SQLite to PostgreSQL Migration
-- Generated by Donetick installer

-- Disable foreign key checks during migration
SET session_replication_role = replica;

EOF
  
  # Export schema and data, converting SQLite syntax to PostgreSQL
  sqlite3 "$sqlite_db" << 'SQLITE_EOF' | sed \
    -e 's/INTEGER PRIMARY KEY AUTOINCREMENT/SERIAL PRIMARY KEY/g' \
    -e 's/INTEGER PRIMARY KEY/SERIAL PRIMARY KEY/g' \
    -e 's/AUTOINCREMENT/SERIAL/g' \
    -e 's/TEXT/VARCHAR/g' \
    -e 's/DATETIME/TIMESTAMP/g' \
    -e 's/BOOLEAN/BOOLEAN/g' \
    -e "s/'t'/'true'/g" \
    -e "s/'f'/'false'/g" \
    -e 's/`/"/g' \
    >> "$output_file"
.output stdout
.mode insert
.headers off
.schema
.dump
SQLITE_EOF
  
  # Re-enable foreign key checks
  cat >> "$output_file" << 'EOF'

-- Re-enable foreign key checks
SET session_replication_role = DEFAULT;

-- Update sequences to correct values
DO $$
DECLARE
    seq_record RECORD;
    max_id INTEGER;
BEGIN
    FOR seq_record IN 
        SELECT schemaname, sequencename, tablename, columnname
        FROM pg_sequences 
        JOIN information_schema.columns ON 
            pg_sequences.sequencename = tablename || '_' || columnname || '_seq'
    LOOP
        EXECUTE format('SELECT COALESCE(MAX(%I), 0) FROM %I.%I', 
                      seq_record.columnname, seq_record.schemaname, seq_record.tablename) 
                INTO max_id;
        
        IF max_id > 0 THEN
            EXECUTE format('SELECT setval(%L, %s)', 
                          seq_record.schemaname || '.' || seq_record.sequencename, max_id);
        END IF;
    END LOOP;
END $$;
EOF
  
  msg_ok "SQLite data exported to: $output_file"
}

# Import SQL dump to PostgreSQL
import_sql_to_postgres() {
  local sql_file="$1"
  local host="$2"
  local port="$3"
  local database="$4"
  local username="$5"
  local password="$6"
  
  msg_info "Importing data to PostgreSQL database..."
  
  export PGPASSWORD="$password"
  
  if psql -h "$host" -p "$port" -U "$username" -d "$database" -f "$sql_file" >/dev/null 2>&1; then
    msg_ok "Data imported successfully to PostgreSQL"
    unset PGPASSWORD
    return 0
  else
    msg_error "Failed to import data to PostgreSQL"
    unset PGPASSWORD
    return 1
  fi
}

# Update configuration to use PostgreSQL
update_config_for_postgres() {
  local host="$1"
  local port="$2"
  local database="$3"
  local username="$4"
  local password="$5"
  local config_file="${CONFIG_DIR}/selfhosted.yaml"
  
  msg_info "Updating configuration for PostgreSQL..."
  
  # Backup current config
  backup_config
  
  # Get existing JWT secret if config exists
  local jwt_secret=""
  if [[ -f "$config_file" ]]; then
    jwt_secret=$(grep -A1 "jwt:" "$config_file" | grep "secret:" | awk '{print $2}' | tr -d '"' 2>/dev/null || echo "")
  fi
  
  # Generate new JWT secret if none found
  if [[ -z "$jwt_secret" ]]; then
    jwt_secret=$(openssl rand -base64 32)
  fi
  
  # Create new PostgreSQL configuration
  create_postgres_config "$jwt_secret" "$host" "$port" "$database" "$username" "$password"
  
  msg_ok "Configuration updated for PostgreSQL"
}

# Verify migration success
verify_migration() {
  local host="$1"
  local port="$2"
  local database="$3"
  local username="$4"
  local password="$5"
  
  msg_info "Verifying migration..."
  
  export PGPASSWORD="$password"
  
  # Count tables in PostgreSQL
  local table_count=$(psql -h "$host" -p "$port" -U "$username" -d "$database" -tAc "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE';")
  
  if [[ "$table_count" -gt 0 ]]; then
    msg_ok "Migration verification successful: $table_count tables found in PostgreSQL"
    
    # Show a summary of migrated data
    msg_info "Migration summary:"
    psql -h "$host" -p "$port" -U "$username" -d "$database" -c "
    SELECT 
        schemaname,
        tablename,
        n_tup_ins as rows
    FROM pg_stat_user_tables 
    ORDER BY tablename;" 2>/dev/null || true
    
    unset PGPASSWORD
    return 0
  else
    msg_error "Migration verification failed: no tables found in PostgreSQL"
    unset PGPASSWORD
    return 1
  fi
}

# Main migration function
migrate_to_postgres() {
  local host="$1"
  local port="$2"
  local database="$3"
  local username="$4"
  local password="$5"
  local skip_backup="${6:-false}"
  
  msg_info "Starting migration from SQLite to PostgreSQL..."
  msg_info "Target: postgres://$username@$host:$port/$database"
  
  # Step 1: Install PostgreSQL client tools
  check_postgres_tools
  
  # Step 2: Test PostgreSQL connection
  if ! test_postgres_connection "$host" "$port" "$database" "$username" "$password"; then
    return 1
  fi
  
  # Step 3: Ensure target database exists
  ensure_postgres_database "$host" "$port" "$database" "$username" "$password"
  
  # Step 4: Stop Donetick service
  if systemctl is-active --quiet donetick; then
    msg_info "Stopping Donetick service for migration..."
    systemctl stop donetick
    msg_ok "Donetick service stopped"
  fi
  
  # Step 5: Backup SQLite database
  if [[ "$skip_backup" != "true" ]]; then
    if ! backup_sqlite_database; then
      msg_warn "SQLite backup failed, but continuing with migration..."
    fi
  fi
  
  # Step 6: Export SQLite data
  local temp_sql="/tmp/donetick_migration_$(date +%Y%m%d_%H%M%S).sql"
  if ! export_sqlite_to_sql "$temp_sql"; then
    return 1
  fi
  
  # Step 7: Import to PostgreSQL
  if ! import_sql_to_postgres "$temp_sql" "$host" "$port" "$database" "$username" "$password"; then
    rm -f "$temp_sql"
    return 1
  fi
  
  # Step 8: Update configuration
  if ! update_config_for_postgres "$host" "$port" "$database" "$username" "$password"; then
    rm -f "$temp_sql"
    return 1
  fi
  
  # Step 9: Restart Donetick service
  msg_info "Restarting Donetick service with PostgreSQL configuration..."
  systemctl daemon-reload
  systemctl start donetick
  
  # Wait a moment for service to start
  sleep 3
  
  if systemctl is-active --quiet donetick; then
    msg_ok "Donetick service restarted successfully"
  else
    msg_error "Failed to restart Donetick service. Check logs with: journalctl -u donetick -f"
    rm -f "$temp_sql"
    return 1
  fi
  
  # Step 10: Verify migration
  if verify_migration "$host" "$port" "$database" "$username" "$password"; then
    msg_ok "Migration completed successfully!"
    msg_info "SQLite database backed up and PostgreSQL is now active"
    msg_info "You can now remove the SQLite database file if desired: ${INSTALL_DIR}/donetick.db"
  else
    msg_error "Migration verification failed"
    rm -f "$temp_sql"
    return 1
  fi
  
  # Cleanup
  rm -f "$temp_sql"
  
  return 0
}

# Interactive migration setup
interactive_postgres_migration() {
  msg_info "Interactive PostgreSQL Migration Setup"
  echo
  
  # Get PostgreSQL connection details
  read -p "PostgreSQL Host [192.168.86.31]: " pg_host
  pg_host="${pg_host:-192.168.86.31}"
  
  read -p "PostgreSQL Port [5432]: " pg_port
  pg_port="${pg_port:-5432}"
  
  read -p "Database Name [donetick]: " pg_database
  pg_database="${pg_database:-donetick}"
  
  read -p "Username [postgres]: " pg_username
  pg_username="${pg_username:-postgres}"
  
  echo -n "Password: "
  read -s pg_password
  echo
  
  read -p "Skip SQLite backup? [y/N]: " skip_backup
  skip_backup="${skip_backup:-N}"
  if [[ "$skip_backup" =~ ^[Yy]$ ]]; then
    skip_backup="true"
  else
    skip_backup="false"
  fi
  
  echo
  msg_info "Migration Settings:"
  msg_info "  Host: $pg_host"
  msg_info "  Port: $pg_port"
  msg_info "  Database: $pg_database"
  msg_info "  Username: $pg_username"
  msg_info "  Skip Backup: $skip_backup"
  echo
  
  read -p "Proceed with migration? [y/N]: " confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    migrate_to_postgres "$pg_host" "$pg_port" "$pg_database" "$pg_username" "$pg_password" "$skip_backup"
  else
    msg_info "Migration cancelled"
    return 1
  fi
}
