#!/bin/bash
# Nagios Deployment Diagnostic Script

echo "=========================================="
echo "🔍 NAGIOS DIAGNOSTIC REPORT"
echo "=========================================="
echo ""

# SSH into Nagios server
NAGIOS_IP="13.233.112.94"
NAGIOS_USER="ubuntu"
NAGIOS_KEY="~/.ssh/deploy-key"

echo "Target: $NAGIOS_IP"
echo ""

# Test SSH connectivity
echo "1️⃣  Testing SSH Connectivity..."
if ssh -i $NAGIOS_KEY -o ConnectTimeout=5 $NAGIOS_USER@$NAGIOS_IP "echo 'SSH: OK'" 2>/dev/null; then
    echo "✅ SSH Connection: OK"
else
    echo "❌ SSH Connection: FAILED"
    exit 1
fi

echo ""
echo "2️⃣  Checking Nagios Service Status..."
ssh -i $NAGIOS_KEY $NAGIOS_USER@$NAGIOS_IP << 'CMDS'
echo "Nagios service status:"
sudo systemctl status nagios 2>/dev/null || echo "Service not found or not running"

echo ""
echo "3️⃣  Checking Apache Service Status..."
echo "Apache service status:"
sudo systemctl status apache2 2>/dev/null || echo "Apache not running"

echo ""
echo "4️⃣  Checking if Nagios Process is Running..."
ps aux | grep -i nagios | grep -v grep || echo "No nagios process found"

echo ""
echo "5️⃣  Checking Nagios Installation..."
if [ -f /usr/local/nagios/bin/nagios ]; then
    echo "✅ Nagios binary found: /usr/local/nagios/bin/nagios"
else
    echo "❌ Nagios binary NOT found"
fi

if [ -f /usr/local/nagios/etc/nagios.cfg ]; then
    echo "✅ Nagios config found: /usr/local/nagios/etc/nagios.cfg"
else
    echo "❌ Nagios config NOT found"
fi

echo ""
echo "6️⃣  Validating Nagios Configuration..."
if [ -f /usr/local/nagios/etc/nagios.cfg ]; then
    /usr/local/nagios/bin/nagios -v /usr/local/nagios/etc/nagios.cfg 2>&1 | head -30
else
    echo "Cannot validate - config file missing"
fi

echo ""
echo "7️⃣  Checking Web Server Configuration..."
if [ -f /etc/apache2/sites-available/nagios.conf ]; then
    echo "✅ Apache Nagios config found"
    echo "Enabled:"
    ls -la /etc/apache2/sites-enabled/ | grep -i nagios
else
    echo "❌ Apache config not found"
fi

echo ""
echo "8️⃣  Checking Port Availability..."
echo "Port 80 (Apache):"
netstat -tlnp 2>/dev/null | grep :80 || echo "Port 80 not listening"

echo ""
echo "Port 5666 (NRPE):"
netstat -tlnp 2>/dev/null | grep :5666 || echo "Port 5666 not listening"

echo ""
echo "9️⃣  Checking Nagios System User..."
id nagios 2>/dev/null || echo "Nagios user not found"

echo ""
echo "10️⃣ Checking File Permissions..."
ls -la /usr/local/nagios/bin/nagios 2>/dev/null || echo "Cannot check nagios binary"
ls -la /usr/local/nagios/etc/ 2>/dev/null | head -5

echo ""
echo "1️⃣1️⃣ Checking Nagios Error Logs..."
if [ -f /var/log/nagios/nagios.log ]; then
    echo "Last 15 lines of nagios.log:"
    tail -15 /var/log/nagios/nagios.log
else
    echo "⚠️  /var/log/nagios/nagios.log not found"
fi

echo ""
echo "1️⃣2️⃣ Checking Apache Error Logs..."
if [ -f /var/log/apache2/error.log ]; then
    echo "Last 10 lines of Apache error.log:"
    tail -10 /var/log/apache2/error.log
else
    echo "Apache log not found"
fi

CMDS

echo ""
echo "=========================================="
echo "📋 DIAGNOSTIC REPORT COMPLETE"
echo "=========================================="
