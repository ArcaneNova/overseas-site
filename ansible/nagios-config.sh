#!/bin/bash

set -e

echo "========================================="
echo "NAGIOS FINAL CONFIGURATION"
echo "========================================="
echo ""

# Stop services
systemctl stop nagios 2>/dev/null || true

# Create config file
cat > /usr/local/nagios/etc/objects/localhost.cfg << 'EOF'
define host{
    host_name               localhost
    alias                   Nagios Server
    address                 127.0.0.1
    check_command           check-host-alive
    max_check_attempts      10
    check_interval          5
    retry_interval          1
    check_period            24x7
    contact_groups          admins
    notification_interval   120
    notification_period     24x7
}

define host{
    host_name               app-server
    alias                   Next.js Application Server
    address                 13.61.181.123
    check_command           check-host-alive
    max_check_attempts      10
    check_interval          5
    retry_interval          1
    check_period            24x7
    contact_groups          admins
    notification_interval   120
    notification_period     24x7
}

define service{
    host_name               localhost
    service_description     CPU Load
    check_command           check_local_load!5.0,4.0!10.0,6.0
    max_check_attempts      10
    check_interval          5
    retry_interval          1
    check_period            24x7
    contact_groups          admins
    notification_interval   120
    notification_period     24x7
}

define service{
    host_name               localhost
    service_description     Disk Usage
    check_command           check_local_disk!20%!10%!/
    max_check_attempts      10
    check_interval          5
    retry_interval          1
    check_period            24x7
    contact_groups          admins
    notification_interval   120
    notification_period     24x7
}

define service{
    host_name               localhost
    service_description     Memory Usage
    check_command           check_local_swap!20!10
    max_check_attempts      10
    check_interval          5
    retry_interval          1
    check_period            24x7
    contact_groups          admins
    notification_interval   120
    notification_period     24x7
}

define service{
    host_name               localhost
    service_description     Nagios Process
    check_command           check_local_procs!250!400!RSZDT
    max_check_attempts      10
    check_interval          5
    retry_interval          1
    check_period            24x7
    contact_groups          admins
    notification_interval   120
    notification_period     24x7
}

define service{
    host_name               app-server
    service_description     Ping
    check_command           check_ping!100.0,20%!500.0,60%
    max_check_attempts      10
    check_interval          5
    retry_interval          1
    check_period            24x7
    contact_groups          admins
    notification_interval   120
    notification_period     24x7
}

define service{
    host_name               app-server
    service_description     SSH
    check_command           check_tcp!-p 22
    max_check_attempts      10
    check_interval          5
    retry_interval          1
    check_period            24x7
    contact_groups          admins
    notification_interval   120
    notification_period     24x7
}

define service{
    host_name               app-server
    service_description     HTTP
    check_command           check_http!-p 80 -u /
    max_check_attempts      10
    check_interval          5
    retry_interval          1
    check_period            24x7
    contact_groups          admins
    notification_interval   120
    notification_period     24x7
}

define service{
    host_name               app-server
    service_description     NRPE
    check_command           check_nrpe!-H 13.61.181.123
    max_check_attempts      10
    check_interval          5
    retry_interval          1
    check_period            24x7
    contact_groups          admins
    notification_interval   120
    notification_period     24x7
}

define service{
    host_name               app-server
    service_description     Remote Load
    check_command           check_nrpe!-H 13.61.181.123 -c check_load
    max_check_attempts      10
    check_interval          5
    retry_interval          1
    check_period            24x7
    contact_groups          admins
    notification_interval   120
    notification_period     24x7
}

define service{
    host_name               app-server
    service_description     Remote Disk
    check_command           check_nrpe!-H 13.61.181.123 -c check_disk
    max_check_attempts      10
    check_interval          5
    retry_interval          1
    check_period            24x7
    contact_groups          admins
    notification_interval   120
    notification_period     24x7
}

define service{
    host_name               app-server
    service_description     Remote Memory
    check_command           check_nrpe!-H 13.61.181.123 -c check_memory
    max_check_attempts      10
    check_interval          5
    retry_interval          1
    check_period            24x7
    contact_groups          admins
    notification_interval   120
    notification_period     24x7
}

define service{
    host_name               app-server
    service_description     Remote Processes
    check_command           check_nrpe!-H 13.61.181.123 -c check_processes
    max_check_attempts      10
    check_interval          5
    retry_interval          1
    check_period            24x7
    contact_groups          admins
    notification_interval   120
    notification_period     24x7
}
EOF

echo "✓ Config file created"

# Fix permissions
chown -R nagios:nagios /usr/local/nagios/var /usr/local/nagios/etc/objects
chmod -R 775 /usr/local/nagios/var

# Validate
echo "✓ Validating config..."
/usr/local/nagios/bin/nagios -v /usr/local/nagios/etc/nagios.cfg 2>&1 | grep -E "^Total|error|error" || echo "Config valid"

# Start services
echo "✓ Starting services..."
systemctl start nagios
sleep 2

# Verify
echo ""
echo "=== SERVICE STATUS ==="
systemctl is-active nagios && echo "✅ Nagios RUNNING" || echo "❌ Nagios FAILED"
systemctl is-active nginx && echo "✅ Nginx RUNNING" || echo "❌ Nginx FAILED"  
systemctl is-active php8.1-fpm && echo "✅ PHP-FPM RUNNING" || echo "❌ PHP-FPM FAILED"

echo ""
echo "========================================="
echo "✅ NAGIOS READY!"
echo "========================================="
echo ""
echo "Access: http://16.16.215.8/nagios/"
echo "User: nagios"
echo "Pass: nagios123"
echo ""
