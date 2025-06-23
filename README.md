# Donetick Modular Installer & Updater

This repository contains a modular installer system for [Donetick](https://github.com/donetick/donetick), an open-source task and chore management application. The installer features a completely refactored modular architecture for better maintainability, with separate libraries for different functionality areas.

## Architecture

The installer now uses a modular architecture with the following components:

### Core Libraries (`lib/`)

- **`common.sh`** - Shared utilities, logging, and configuration constants
- **`github.sh`** - GitHub API interactions and release management
- **`system.sh`** - System operations (user creation, permissions, architecture detection)
- **`config.sh`** - Configuration file management and backup/restore
- **`service.sh`** - Systemd service management and auto-updater setup

### Operation Scripts (`scripts/`)

- **`install.sh`** - Fresh installation logic
- **`update.sh`** - Update existing installation logic
- **`auto-updater.sh`** - Automatic updater for cron jobs

### Templates (`templates/`)

- **`donetick.service`** - Systemd service template
- **`selfhosted.yaml`** - Configuration file template

### Main Script

- **`donetick.sh`** - Main orchestrator that determines and executes the appropriate operation

## Key Improvements

### Modular Architecture

- **Separation of Concerns**: Each library handles specific functionality (GitHub API, system operations, configuration, etc.)
- **Reusability**: Libraries can be used independently and tested separately
- **Maintainability**: Easier to update and maintain individual components
- **Remote Loading**: Libraries and templates can be downloaded from remote sources if not available locally

### Smart Configuration Management

- **Backup & Restore**: Automatically backs up configuration during updates and restores it
- **Breaking Change Detection**: Checks release notes for breaking changes before updating
- **Template System**: Configuration templates can be stored remotely and customized during installation

### Enhanced Update System

- **Intelligent Updates**: Only updates when newer versions are available
- **Self-Updating Updater**: The auto-updater script can update itself
- **Comprehensive Ownership**: Ensures proper file ownership throughout the installation and update process
- **Graceful Failure Handling**: Better error handling and recovery options
- **Breaking Change Detection**: Automatically scans release notes and preserves configurations when needed
- **Template-Based Configuration**: Uses remote templates for consistency across installations

### Default Behavior

- **Fresh Installation**: If Donetick is not installed, performs a fresh installation
- **Automatic Updates**: If Donetick is installed but not the latest version, performs an update
- **Force Options**: Can force reinstallation or updates regardless of current state

## About Donetick

Donetick is a modern, feature-rich task and chore management application designed for individuals and families. It offers:

- **Collaborative Task Management**: Create and manage tasks with family and friends through shared circles
- **Natural Language Processing**: Create tasks using plain English descriptions
- **Advanced Scheduling**: Flexible recurrence patterns, adaptive scheduling, and completion windows
- **Gamification**: Points system and analytics to track productivity
- **Multi-Platform Notifications**: Support for Telegram, Discord, Pushover
- **File Attachments**: Upload files and photos to tasks
- **REST API**: Full programmatic access for integrations
- **Home Assistant Integration**: Manage tasks directly from Home Assistant
- **Multi-Factor Authentication**: TOTP-based MFA with backup codes
- **OAuth2 Support**: Google OAuth and other providers

## Installation

### Quick Install

To install Donetick on a compatible Debian-based system, run this command with root privileges:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/daVinci2793/proxmox-helper/main/donetick.sh)"
```

### Installation Options

The script supports several command-line options:

```bash
# Standard installation with automatic updates enabled
bash -c "$(curl -fsSL https://raw.githubusercontent.com/daVinci2793/proxmox-helper/main/donetick.sh)"

# Check for updates without installing
bash -c "$(curl -fsSL https://raw.githubusercontent.com/daVinci2793/proxmox-helper/main/donetick.sh)" -- --check

# Force installation/update even if up to date
bash -c "$(curl -fsSL https://raw.githubusercontent.com/daVinci2793/proxmox-helper/main/donetick.sh)" -- --force

# Install without setting up automatic updates
bash -c "$(curl -fsSL https://raw.githubusercontent.com/daVinci2793/proxmox-helper/main/donetick.sh)" -- --disable-auto-updates

# Show help
bash -c "$(curl -fsSL https://raw.githubusercontent.com/daVinci2793/proxmox-helper/main/donetick.sh)" -- --help
```

### What the Script Does

The script will automatically:

- Install required dependencies (curl, sqlite3, openssl, ca-certificates, cron).
- Create a dedicated system user (`donetick`).
- Download the latest version of Donetick for your architecture (x86_64/amd64, arm64, armv7).
- Set up a comprehensive default configuration file with all available options.
- Create and enable a systemd service to run Donetick on boot.
- Configure automatic updates (runs daily at 3:00 AM by default).
- Create an updater script at `/usr/local/bin/donetick-updater` for manual updates.

## Default Configuration

- **Install Directory**: `/opt/donetick`
- **Port**: `2021`
- **Database**: SQLite (stored in `/opt/donetick/donetick.db`)
- **Config File**: `/opt/donetick/config/selfhosted.yaml`
- **Service User**: `donetick`

## First Time Setup

1. After installation, access Donetick at `http://<SERVER_IP>:2021`
2. Create your first admin user account.
3. Start creating tasks and managing your to-do lists!

## Configuration

### View Installation Details

A file with the application URL is created after installation.

```bash
cat /root/donetick.creds
```

### Edit Configuration

```bash
nano /opt/donetick/config/selfhosted.yaml
```

After editing the configuration, restart the service for the changes to take effect:

```bash
systemctl restart donetick
```

### Common Configuration Options

#### Enable Notifications

Edit `/opt/donetick/config/selfhosted.yaml`:

**Telegram Bot:**

```yaml
telegram:
  token: "your_bot_token_here"
```

**Pushover:**

```yaml
pushover:
  token: "your_pushover_token_here"
```

#### OAuth2 Setup (Google)

```yaml
oauth2:
  client_id: "your_google_client_id"
  client_secret: "your_google_client_secret"
  auth_url: "https://accounts.google.com/o/oauth2/auth"
  token_url: "https://oauth2.googleapis.com/token"
  user_info_url: "https://www.googleapis.com/oauth2/v2/userinfo"
  redirect_url: "http://your-donetick-instance.com/auth/oauth2"
```

#### Email Notifications

```yaml
email:
  host: "smtp.gmail.com"
  port: "587"
  key: "your_smtp_password"
  email: "your_email@gmail.com"
  appHost: "http://your-domain:2021"
```

## Service Management

### Check Service Status

```bash
systemctl status donetick
```

### View Logs

```bash
# Live service logs
journalctl -u donetick -f

# Update logs
tail -f /var/log/donetick-updater.log
```

### Start/Stop/Restart Service

```bash
systemctl start donetick
systemctl stop donetick
systemctl restart donetick
```

### Version Information

```bash
# Check current installed version
cat /opt/Donetick_version.txt

# Check for available updates
/usr/local/bin/donetick-updater || bash -c "$(curl -fsSL https://raw.githubusercontent.com/daVinci2793/proxmox-helper/main/donetick.sh)" -- --check

# View installation details
cat /root/donetick.creds
```

## Updates

The script includes comprehensive update functionality with both manual and automatic options.

### Manual Updates

To update Donetick to the latest version:

```bash
# Re-run the installer script (detects existing installation automatically)
bash -c "$(curl -fsSL https://raw.githubusercontent.com/daVinci2793/proxmox-helper/main/donetick.sh)"

# Or use the local updater script
/usr/local/bin/donetick-updater

# Check for updates without installing
bash -c "$(curl -fsSL https://raw.githubusercontent.com/daVinci2793/proxmox-helper/main/donetick.sh)" -- --check
```

### Automatic Updates

By default, the script sets up automatic updates that run daily at 3:00 AM. The automatic updater:

- Checks for new versions on GitHub
- Downloads and installs updates automatically if available
- Preserves your configuration and data
- Logs all activities to `/var/log/donetick-updater.log`

#### Automatic Update Management

```bash
# View automatic update configuration
cat /etc/cron.d/donetick-updates

# View update logs
tail -f /var/log/donetick-updater.log

# Disable automatic updates
rm /etc/cron.d/donetick-updates

# Re-enable automatic updates
bash -c "$(curl -fsSL https://raw.githubusercontent.com/daVinci2793/proxmox-helper/main/donetick.sh)" -- --setup-auto-updates
```

### Update Process

During updates, the script:

1. **Checks for breaking changes** in release notes
2. **Automatically backs up** your current configuration
3. **Stops the Donetick service** safely
4. **Downloads and installs** the new version
5. **Restores your configuration** from backup (unless breaking changes detected)
6. **Sets proper ownership** on all files and database
7. **Restarts the service** with the new version

Configuration backups are stored as: `/opt/donetick/config/selfhosted.yaml.backup.YYYYMMDD_HHMMSS`

### Breaking Change Detection

The update system includes intelligent breaking change detection:

- **Automatic Scanning**: Checks release notes for keywords like "breaking", "migration", "config change"
- **Preserved Backups**: If breaking changes are detected, your configuration backup is preserved
- **Manual Review Required**: Updates with breaking changes require manual intervention
- **Clear Guidance**: Provides links to release notes for review

If breaking changes are detected, you'll see a warning like:

```bash
WARNING: Potential breaking changes detected in v2.0.0
WARNING: Configuration backup preserved for manual review
WARNING: See: https://github.com/donetick/donetick/releases/tag/v2.0.0
```

## Automatic Update System

The installer sets up a comprehensive automatic update system that keeps your Donetick installation current with the latest releases.

### How It Works

- **Daily Checks**: The system checks for updates daily at 3:00 AM
- **Smart Updates**: Only downloads and installs if a newer version is available
- **Configuration Preservation**: Your settings and data are never touched during updates
- **Automatic Backups**: Configuration is backed up before each update
- **Logging**: All update activities are logged for troubleshooting

### Update Components

| Component | Location | Purpose |
|-----------|----------|---------|
| Updater Script | `/usr/local/bin/donetick-updater` | Main update logic |
| Cron Job | `/etc/cron.d/donetick-updates` | Scheduled execution |
| Update Logs | `/var/log/donetick-updater.log` | Activity logging |
| Version File | `/opt/Donetick_version.txt` | Current version tracking |

### Manual Update Control

```bash
# Run update check manually
/usr/local/bin/donetick-updater

# View recent update activity
tail -20 /var/log/donetick-updater.log

# Temporarily disable automatic updates
chmod -x /usr/local/bin/donetick-updater

# Re-enable automatic updates
chmod +x /usr/local/bin/donetick-updater

# Completely remove automatic updates
rm /etc/cron.d/donetick-updates /usr/local/bin/donetick-updater
```

## Database Management

### Backup Database

```bash
# Create backup
sqlite3 /opt/donetick/donetick.db ".backup /opt/donetick/donetick_backup_$(date +%Y%m%d_%H%M%S).db"
```

### Restore Database

```bash
# Stop service
systemctl stop donetick

# Restore backup
cp /opt/donetick/donetick_backup_YYYYMMDD_HHMMSS.db /opt/donetick/donetick.db

# Set permissions
chown donetick:donetick /opt/donetick/donetick.db

# Start service
systemctl start donetick
```

## File Storage

By default, Donetick uses local storage for file attachments. Files are stored in the data directory alongside the database.

### Cloud Storage (Optional)

Donetick supports S3-compatible storage. Edit the configuration file to add cloud storage settings:

```yaml
storage:
  type: "s3"
  endpoint: "your-s3-endpoint"
  bucket: "your-bucket-name"
  access_key: "your-access-key"
  secret_key: "your-secret-key"
```

## Mobile App Support

Donetick includes official mobile apps for iOS and Android built with Capacitor. The script is pre-configured with the necessary CORS settings for Android app compatibility.

### Android App Setup

1. Install the Donetick Android app from the Google Play Store or F-Droid
2. In the app settings, configure your server URL as `http://<LXC_IP>:2021`
3. If using HTTPS, ensure your SSL certificate is properly configured
4. The server includes the required CORS origins:
   - `https://localhost`
   - `capacitor://localhost`
   - Development origins for local testing

### iOS App Setup

Similar to Android, configure the server URL in the iOS app settings.

## Integrations

### Home Assistant

Install the official Donetick custom component in Home Assistant:

1. Add the Donetick integration
2. Configure with your Donetick URL and API credentials
3. Tasks will appear as entities in Home Assistant

### API Access

The REST API is available at `http://<LXC_IP>:2021/api/`

Generate an API token in the Donetick web interface under Settings > API.

## Troubleshooting

### Service Won't Start

1. Check the logs: `journalctl -u donetick -f`
2. Verify configuration: `nano /opt/donetick/config/selfhosted.yaml`
3. Check permissions: `ls -la /opt/donetick/`
4. Verify file ownership: `ls -la /opt/donetick/donetick.db`
5. Fix ownership if needed: `sudo chown -R donetick:donetick /opt/donetick`

### Database Issues

1. Check if database file exists: `ls -la /opt/donetick/donetick.db`
2. Verify SQLite installation: `sqlite3 --version`
3. Test database connectivity: `sqlite3 /opt/donetick/donetick.db ".tables"`

### Update Issues

1. Check update logs: `tail -f /var/log/donetick-updater.log`
2. Verify internet connectivity: `curl -I https://api.github.com/repos/donetick/donetick/releases/latest`
3. Check if updater script exists: `ls -la /usr/local/bin/donetick-updater`
4. Test manual update: `/usr/local/bin/donetick-updater`
5. Force reinstall: `bash -c "$(curl -fsSL https://raw.githubusercontent.com/daVinci2793/proxmox-helper/main/donetick.sh)" -- --force`

### Automatic Updates Not Working

1. Check cron job: `cat /etc/cron.d/donetick-updates`
2. Verify cron service: `systemctl status cron` or `systemctl status cronie`
3. Check for recent update attempts: `grep donetick /var/log/syslog`
4. Test updater script manually: `/usr/local/bin/donetick-updater`

### Port Already in Use

If port 2021 is already in use, edit the configuration:

```yaml
server:
  port: 2022  # or another available port
```

Then restart the service: `systemctl restart donetick`

## Security Considerations

- The script creates a dedicated `donetick` user with minimal privileges
- Systemd service includes security hardening options
- JWT secret is automatically generated during installation
- Database is stored locally with appropriate file permissions

## Support

- **GitHub**: [https://github.com/donetick/donetick](https://github.com/donetick/donetick)
- **Discord**: [https://discord.gg/6hSH6F33q7](https://discord.gg/6hSH6F33q7)
- **Reddit**: [https://www.reddit.com/r/donetick](https://www.reddit.com/r/donetick)
- **Documentation**: Check the GitHub repository for detailed documentation

## License

This script is provided under the MIT License, same as the Proxmox Helper Scripts project.
Donetick itself is licensed under AGPLv3.
