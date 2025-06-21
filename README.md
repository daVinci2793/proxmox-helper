# Donetick Proxmox Helper Script

This script creates a Proxmox LXC container with Donetick, an open-source task and chore management application.

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

To create a new Proxmox VE Donetick LXC container, run this command in the Proxmox VE Shell:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/daVinci2793/proxmox-helper/main/donetick.sh)"
```

## Default Settings

- **OS**: Debian 12
- **CPU**: 1 vCPU
- **RAM**: 1GB
- **Storage**: 4GB
- **Network**: DHCP
- **Unprivileged**: Yes

## Default Configuration

- **Port**: 2021
- **Database**: SQLite (stored in `/opt/donetick/data/donetick.db`)
- **Config File**: `/opt/donetick/config/selfhosted.yaml`
- **Data Directory**: `/opt/donetick/data`
- **Service User**: `donetick`

## First Time Setup

1. After installation, access Donetick at `http://<LXC_IP>:2021`
2. Create your first admin user account
3. Start creating tasks and managing your to-do lists!

## Configuration

### View Configuration Details

```bash
cat /root/donetick.creds
```

### Edit Configuration

```bash
nano /opt/donetick/config/selfhosted.yaml
```

After editing the configuration, restart the service:

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
  redirect_url: "http://your-domain:2021/auth/callback"
  name: "google"
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
journalctl -u donetick -f
```

### Start/Stop/Restart Service

```bash
systemctl start donetick
systemctl stop donetick
systemctl restart donetick
```

## Updates

The script includes an automatic update function. To update Donetick to the latest version:

1. Run the script again with the same command
2. The script will detect the existing installation and offer to update it
3. Configuration and data are preserved during updates

## Database Management

### Backup Database

```bash
# Create backup
sqlite3 /opt/donetick/data/donetick.db ".backup /opt/donetick/data/donetick_backup_$(date +%Y%m%d_%H%M%S).db"
```

### Restore Database

```bash
# Stop service
systemctl stop donetick

# Restore backup
cp /opt/donetick/data/donetick_backup_YYYYMMDD_HHMMSS.db /opt/donetick/data/donetick.db

# Set permissions
chown donetick:donetick /opt/donetick/data/donetick.db

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

### Database Issues

1. Check if database file exists: `ls -la /opt/donetick/data/`
2. Verify SQLite installation: `sqlite3 --version`
3. Test database connectivity: `sqlite3 /opt/donetick/data/donetick.db ".tables"`

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
