#!/bin/bash

# Donetick Installation Test Script
# This script tests if Donetick is properly installed and running

echo "Testing Donetick Installation..."
echo "================================="

# Test 1: Check if donetick binary exists
echo -n "1. Checking Donetick binary... "
if [ -f "/opt/donetick/donetick" ] && [ -x "/opt/donetick/donetick" ]; then
    echo "✓ Found"
else
    echo "✗ Missing or not executable"
    exit 1
fi

# Test 2: Check if configuration exists
echo -n "2. Checking configuration file... "
if [ -f "/opt/donetick/config/selfhosted.yaml" ]; then
    echo "✓ Found"
else
    echo "✗ Missing"
    exit 1
fi

# Test 3: Check if data directory exists
echo -n "3. Checking data directory... "
if [ -d "/opt/donetick/data" ]; then
    echo "✓ Found"
else
    echo "✗ Missing"
    exit 1
fi

# Test 4: Check if systemd service exists
echo -n "4. Checking systemd service... "
if [ -f "/etc/systemd/system/donetick.service" ]; then
    echo "✓ Found"
else
    echo "✗ Missing"
    exit 1
fi

# Test 5: Check if service is enabled
echo -n "5. Checking if service is enabled... "
if systemctl is-enabled donetick &>/dev/null; then
    echo "✓ Enabled"
else
    echo "✗ Not enabled"
fi

# Test 6: Check if service is running
echo -n "6. Checking if service is running... "
if systemctl is-active donetick &>/dev/null; then
    echo "✓ Running"
else
    echo "✗ Not running"
    echo "   Try: systemctl start donetick"
fi

# Test 7: Check if port 2021 is listening
echo -n "7. Checking if port 2021 is listening... "
if netstat -tuln 2>/dev/null | grep -q ":2021 " || ss -tuln 2>/dev/null | grep -q ":2021 "; then
    echo "✓ Listening"
else
    echo "✗ Not listening"
fi

# Test 8: Check HTTP response
echo -n "8. Testing HTTP response... "
if curl -s -o /dev/null -w "%{http_code}" http://localhost:2021 | grep -q "200"; then
    echo "✓ Responding"
elif curl -s -o /dev/null -w "%{http_code}" http://localhost:2021 | grep -q "30[0-9]"; then
    echo "✓ Responding (redirect)"
else
    echo "✗ Not responding"
    echo "   Check logs: journalctl -u donetick -f"
fi

# Test 9: Check database
echo -n "9. Checking database... "
if [ -f "/opt/donetick/data/donetick.db" ]; then
    if sqlite3 /opt/donetick/data/donetick.db ".tables" &>/dev/null; then
        echo "✓ Database accessible"
    else
        echo "✗ Database corrupted"
    fi
else
    echo "⚠ Database not yet created (normal for first run)"
fi

# Test 10: Check permissions
echo -n "10. Checking file permissions... "
DONETICK_USER=$(stat -c '%U' /opt/donetick/donetick 2>/dev/null)
DONETICK_GROUP=$(stat -c '%G' /opt/donetick/donetick 2>/dev/null)
if [ "$DONETICK_USER" = "donetick" ] && [ "$DONETICK_GROUP" = "donetick" ]; then
    echo "✓ Correct ownership"
else
    echo "✗ Incorrect ownership (expected donetick:donetick, got $DONETICK_USER:$DONETICK_GROUP)"
fi

echo
echo "Installation Summary:"
echo "===================="

# Get version if available
if [ -f "/opt/Donetick_version.txt" ]; then
    VERSION=$(cat /opt/Donetick_version.txt)
    echo "Version: $VERSION"
fi

# Get service status
SERVICE_STATUS=$(systemctl is-active donetick 2>/dev/null || echo "unknown")
echo "Service Status: $SERVICE_STATUS"

# Get IP address
IP_ADDRESS=$(hostname -I | awk '{print $1}')
echo "Access URL: http://$IP_ADDRESS:2021"

# Show credentials location
if [ -f "/root/donetick.creds" ]; then
    echo "Credentials: /root/donetick.creds"
fi

echo
echo "Quick Commands:"
echo "==============="
echo "View logs:          journalctl -u donetick -f"
echo "Restart service:    systemctl restart donetick"
echo "Edit config:        nano /opt/donetick/config/selfhosted.yaml"
echo "View credentials:   cat /root/donetick.creds"

if [ "$SERVICE_STATUS" = "active" ]; then
    echo
    echo "✓ Donetick appears to be running correctly!"
    echo "✓ You can access it at: http://$IP_ADDRESS:2021"
else
    echo
    echo "⚠ Donetick may not be running properly."
    echo "⚠ Check the service logs: journalctl -u donetick -f"
fi
