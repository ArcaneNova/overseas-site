#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=========================================${NC}"
echo -e "${YELLOW}NAGIOS COMPLETE CONFIGURATION FIX${NC}"
echo -e "${YELLOW}=========================================${NC}"
echo ""

if [ "$EUID" -ne 0 ]; then 
   echo -e "${RED}ERROR: This script must be run as root${NC}"
   exit 1
fi

echo -e "${YELLOW}[1/10] Stopping services...${NC}"
systemctl stop nginx nagios 2>/dev/null || true

echo -e "${YELLOW}[2/10] Removing default Nginx configs...${NC}"
rm -f /etc/nginx/sites-enabled/default
rm -f /etc/nginx/sites-available/default

echo -e "${YELLOW}[3/10] Creating working Nginx config for Nagios...${NC}"
tee /etc/nginx/sites-available/nagios > /dev/null << 'NGINX'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;

    client_max_body_size 50M;
    proxy_read_timeout 300s;
    proxy_connect_timeout 300s;
    proxy_send_timeout 300s;

    # Block all by default
    location / {
        return 403;
    }

    # Main Nagios web interface
    location /nagios/ {
        alias /usr/local/nagios/share/;
        index index.php index.html;

        # Authentication required
        auth_basic "Nagios Access";
        auth_basic_user_file /usr/local/nagios/etc/htpasswd.users;

        # Static assets (CSS, JS, images)
        location ~ ^/nagios/.*\.(css|js|png|jpg|jpeg|gif|ico|woff|woff2|ttf|svg|eot)$ {
            alias /usr/local/nagios/share/;
            access_log off;
            expires 30d;
            add_header Cache-Control "public, immutable";
        }

        # PHP files handler
        location ~ ^/nagios/.*\.php$ {
            include fastcgi_params;
            fastcgi_pass unix:/run/php/php-fpm.sock;
            fastcgi_index index.php;
            fastcgi_param SCRIPT_FILENAME /usr/local/nagios/share$fastcgi_script_name;
            fastcgi_param REMOTE_USER $remote_user;
            fastcgi_param REMOTE_ADDR $remote_addr;
            fastcgi_buffer_size 128k;
            fastcgi_buffers 256 16k;
        }
    }

    # CGI scripts for Nagios (command execution, etc)
    location /nagios/cgi-bin/ {
        alias /usr/local/nagios/sbin/;

        auth_basic "Nagios Access";
        auth_basic_user_file /usr/local/nagios/etc/htpasswd.users;

        location ~ ^/nagios/cgi-bin/.*\.cgi$ {
            include fastcgi_params;
            fastcgi_pass unix:/run/php/php-fpm.sock;
            fastcgi_param SCRIPT_FILENAME /usr/local/nagios/sbin$fastcgi_script_name;
            fastcgi_param REMOTE_USER $remote_user;
            fastcgi_param REMOTE_ADDR $remote_addr;
            fastcgi_buffer_size 128k;
            fastcgi_buffers 256 16k;
        }
    }

    error_log /var/log/nginx/nagios_error.log warn;
    access_log /var/log/nginx/nagios_access.log combined;
}
NGINX

echo -e "${YELLOW}[4/10] Enabling Nagios Nginx config...${NC}"
ln -sf /etc/nginx/sites-available/nagios /etc/nginx/sites-enabled/nagios

echo -e "${YELLOW}[5/10] Testing Nginx config...${NC}"
if ! nginx -t > /dev/null 2>&1; then
    echo -e "${RED}Nginx config test failed!${NC}"
    nginx -t
    exit 1
fi

echo -e "${YELLOW}[6/10] Updating Nagios hosts configuration...${NC}"
tee /usr/local/nagios/etc/objects/localhost.cfg > /dev/null << 'HOSTS'
define host{
    use                     local-host
    host_name               localhost
    alias                   Nagios Server (Monitoring)
    address                 127.0.0.1
}

define host{
    use                     local-host
    host_name               app-server
    alias                   Next.js Application Server
    address                 13.61.181.123
    contact_groups          admins
}

# ===== LOCALHOST SERVICES =====
define service{
    use                     local-service
    host_name               localhost
    service_description     CPU Load
    check_command           check_local_load!5.0,4.0!10.0,6.0
}

define service{
    use                     local-service
    host_name               localhost
    service_description     Disk Usage /
    check_command           check_local_disk!20%!10%!/
}

define service{
    use                     local-service
    host_name               localhost
    service_description     Memory Usage
    check_command           check_local_swap!20!10
}

define service{
    use                     local-service
    host_name               localhost
    service_description     Nagios Process
    check_command           check_local_procs!250!400!RSZDT
}

# ===== APP SERVER SERVICES =====
define service{
    use                     local-service
    host_name               app-server
    service_description     Ping
    check_command           check_ping!100.0,20%!500.0,60%
}

define service{
    use                     local-service
    host_name               app-server
    service_description     SSH
    check_command           check_tcp!-p 22
}

define service{
    use                     local-service
    host_name               app-server
    service_description     HTTP Port 80
    check_command           check_http!-p 80 -u /
}

define service{
    use                     local-service
    host_name               app-server
    service_description     Nginx Status
    check_command           check_http!-p 80 -u /health
}

define service{
    use                     local-service
    host_name               app-server
    service_description     NRPE Agent
    check_command           check_nrpe!-H 13.61.181.123 -p 5666 -c check_load
}

define service{
    use                     local-service
    host_name               app-server
    service_description     Remote CPU Load
    check_command           check_nrpe!-H 13.61.181.123 -p 5666 -c check_load
}

define service{
    use                     local-service
    host_name               app-server
    service_description     Remote Disk Free
    check_command           check_nrpe!-H 13.61.181.123 -p 5666 -c check_disk
}

define service{
    use                     local-service
    host_name               app-server
    service_description     Remote Memory
    check_command           check_nrpe!-H 13.61.181.123 -p 5666 -c check_memory
}

define service{
    use                     local-service
    host_name               app-server
    service_description     Remote Processes
    check_command           check_nrpe!-H 13.61.181.123 -p 5666 -c check_processes
}

define service{
    use                     local-service
    host_name               app-server
    service_description     Next.js Application
    check_command           check_http!-p 80 -u /api/health -H app-server
}
HOSTS

echo -e "${YELLOW}[7/10] Fixing Nagios permissions...${NC}"
chown -R nagios:nagios /usr/local/nagios
chmod 755 /usr/local/nagios/share
chmod 755 /usr/local/nagios/sbin

echo -e "${YELLOW}[8/10] Verifying Nagios configuration...${NC}"
if ! /usr/local/nagios/bin/nagios -v /usr/local/nagios/etc/nagios.cfg 2>&1 | grep -q "0 error"; then
    echo -e "${RED}Nagios configuration check failed!${NC}"
    /usr/local/nagios/bin/nagios -v /usr/local/nagios/etc/nagios.cfg
    exit 1
fi

echo -e "${YELLOW}[9/10] Starting services...${NC}"
systemctl start php-fpm
systemctl start nginx
sleep 1
systemctl start nagios

sleep 2

echo -e "${YELLOW}[10/10] Verifying services...${NC}"
echo ""

if systemctl is-active nginx > /dev/null; then
    echo -e "${GREEN}✓ Nginx is running${NC}"
else
    echo -e "${RED}✗ Nginx failed to start${NC}"
    systemctl status nginx
    exit 1
fi

if systemctl is-active nagios > /dev/null; then
    echo -e "${GREEN}✓ Nagios is running${NC}"
else
    echo -e "${RED}✗ Nagios failed to start${NC}"
    systemctl status nagios
    exit 1
fi

if systemctl is-active php-fpm > /dev/null; then
    echo -e "${GREEN}✓ PHP-FPM is running${NC}"
else
    echo -e "${RED}✗ PHP-FPM failed to start${NC}"
fi

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}✅ NAGIOS CONFIGURATION COMPLETE!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo -e "${GREEN}Web Interface:${NC}"
echo -e "  URL: ${YELLOW}http://16.16.215.8/nagios/${NC}"
echo -e "  Username: ${YELLOW}nagios${NC}"
echo -e "  Password: ${YELLOW}nagios123${NC}"
echo ""
echo -e "${GREEN}Hosts Monitored:${NC}"
echo -e "  1. localhost (Nagios Server)"
echo -e "  2. app-server (13.61.181.123 - Next.js App)"
echo ""
echo -e "${GREEN}Services:${NC}"
echo -e "  Localhost: 4 services (CPU, Disk, Memory, Process)"
echo -e "  App Server: 11 services"
echo -e "    • Ping"
echo -e "    • SSH"
echo -e "    • HTTP Port 80"
echo -e "    • Nginx Status"
echo -e "    • NRPE Agent"
echo -e "    • Remote CPU Load"
echo -e "    • Remote Disk"
echo -e "    • Remote Memory"
echo -e "    • Remote Processes"
echo -e "    • Next.js Application"
echo ""
echo -e "${GREEN}Total: 15 Services${NC}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo -e "  1. Open http://16.16.215.8/nagios/ in browser"
echo -e "  2. Login with nagios/nagios123"
echo -e "  3. View Tactical Overview"
echo -e "  4. Check all hosts and services"
echo -e "  5. Verify all tabs work without errors"
echo ""
echo -e "${GREEN}Logs available at:${NC}"
echo -e "  Nginx Error: tail -f /var/log/nginx/nagios_error.log"
echo -e "  Nagios: tail -f /usr/local/nagios/var/nagios.log"
echo ""
