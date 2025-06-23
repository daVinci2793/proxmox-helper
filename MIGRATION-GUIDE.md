# PostgreSQL Migration Guide

This guide explains how to migrate your Donetick installation from SQLite to PostgreSQL.

## Prerequisites

1. **Existing Donetick Installation**: You must have Donetick installed and running with SQLite
2. **PostgreSQL Server**: A running PostgreSQL server (in your case: `192.168.86.31:5432`)
3. **Database Access**: Credentials to connect to the PostgreSQL server
4. **Root Access**: The migration must be run as root

## Migration Methods

### Method 1: Using the Main Installer (Recommended)

```bash
sudo ./donetick.sh --migrate-to-postgres
```

This will launch an interactive migration wizard that guides you through the process.

### Method 2: Using the Dedicated Migration Script

#### Interactive Mode

```bash
sudo ./migrate-postgres.sh
# or
sudo ./migrate-postgres.sh --interactive
```

#### Non-Interactive Mode

```bash
sudo ./migrate-postgres.sh \
  --host 192.168.86.31 \
  --port 5432 \
  --database donetick \
  --username postgres \
  --password your_password
```

#### Dry Run (Preview)

```bash
sudo ./migrate-postgres.sh --dry-run
```

## Migration Process

The migration performs the following steps:

1. **Pre-flight Checks**
   - Verifies Donetick is installed
   - Checks for SQLite database
   - Installs PostgreSQL client tools if needed

2. **Database Preparation**
   - Tests PostgreSQL connection
   - Creates target database if it doesn't exist

3. **Service Management**
   - Stops Donetick service gracefully
   - Ensures clean shutdown

4. **Data Migration**
   - Backs up SQLite database to `/opt/donetick/backup/`
   - Exports SQLite data to PostgreSQL-compatible SQL
   - Imports data to PostgreSQL

5. **Configuration Update**
   - Backs up current configuration
   - Updates `selfhosted.yaml` with PostgreSQL settings
   - Preserves existing JWT secret and other settings

6. **Service Restart**
   - Reloads systemd configuration
   - Starts Donetick with new database

7. **Verification**
   - Confirms migration success
   - Displays data summary

## Configuration Changes

### Before Migration (SQLite)

```yaml
database:
  type: "sqlite"
  migration: true
```

### After Migration (PostgreSQL)

```yaml
database:
  type: "postgres"
  host: "192.168.86.31"
  port: 5432
  name: "donetick"
  user: "postgres"
  password: "your_password"
  sslmode: "disable"
  migration: true
```

## Files Created/Modified

### Created Files

- `/opt/donetick/backup/donetick_sqlite_backup_TIMESTAMP.db` - SQLite backup
- `/opt/donetick/config/selfhosted.yaml.backup.TIMESTAMP` - Configuration backup

### Modified Files

- `/opt/donetick/config/selfhosted.yaml` - Updated with PostgreSQL settings

## PostgreSQL Database Setup

Your PostgreSQL server should be configured to accept connections. Here's a basic setup:

```sql
-- Connect to PostgreSQL as superuser
CREATE USER donetick WITH PASSWORD 'secure_password';
CREATE DATABASE donetick OWNER donetick;
GRANT ALL PRIVILEGES ON DATABASE donetick TO donetick;
```

## Troubleshooting

### Connection Issues

```bash
# Test connection manually
psql -h 192.168.86.31 -p 5432 -U postgres -d donetick -c "SELECT 1;"
```

### Service Won't Start

```bash
# Check service status
systemctl status donetick

# View logs
journalctl -u donetick -f

# Check configuration
cat /opt/donetick/config/selfhosted.yaml
```

### Rollback to SQLite

If the migration fails, you can restore from backup:

```bash
# Stop service
sudo systemctl stop donetick

# Restore configuration backup
sudo cp /opt/donetick/config/selfhosted.yaml.backup.* /opt/donetick/config/selfhosted.yaml

# Restore database backup (if needed)
sudo cp /opt/donetick/backup/donetick_sqlite_backup_* /opt/donetick/donetick.db

# Fix permissions
sudo chown -R donetick:donetick /opt/donetick

# Start service
sudo systemctl start donetick
```

## Post-Migration

After successful migration:

1. **Verify Data**: Log into Donetick and verify all data is present
2. **Test Functionality**: Create/edit tasks to ensure everything works
3. **Remove SQLite**: Once confident, you can remove the old SQLite database:

   ```bash
   sudo rm /opt/donetick/donetick.db
   ```

4. **Update Backups**: Update your backup procedures to backup PostgreSQL instead of SQLite

## Security Considerations

- **Database Credentials**: Store PostgreSQL credentials securely
- **Network Security**: Consider using SSL/TLS for database connections
- **Firewall**: Ensure proper firewall rules for PostgreSQL access
- **Regular Backups**: Implement regular PostgreSQL backups

## Advanced Options

### Custom Migration Parameters

```bash
# Skip SQLite backup (faster, but risky)
./migrate-postgres.sh --skip-backup

# Use custom database name
./migrate-postgres.sh --database my_donetick_db

# Use SSL connection
# (Modify the script to set sslmode: "require" in config)
```

### Migration Monitoring

```bash
# Monitor migration progress
tail -f /var/log/donetick-updater.log

# Check PostgreSQL activity
psql -h 192.168.86.31 -U postgres -c "SELECT * FROM pg_stat_activity WHERE datname = 'donetick';"
```

## Support

If you encounter issues:

1. Check the logs: `journalctl -u donetick -f`
2. Verify PostgreSQL connectivity
3. Ensure all dependencies are installed
4. Review the migration script output for error messages
5. Use the dry-run mode to preview changes before executing
