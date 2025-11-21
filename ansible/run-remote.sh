#!/bin/bash

# Run THIS on your LOCAL system to copy and execute the config on the remote Nagios server
# Usage: bash run-remote.sh

REMOTE_USER="ubuntu"
REMOTE_IP="16.16.215.8"
SCRIPT_NAME="nagios-config.sh"

echo "========================================="
echo "Copying script to remote server..."
echo "========================================="
echo ""

# Create the inline script that will be executed on remote
REMOTE_SCRIPT='#!/bin/bash
set -e
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
NC="\033[0m"
echo -e "${YELLOW}=========================================${NC}"
echo -e "${YELLOW}NAGIOS COMPLETE CONFIGURATION${NC}"
echo -e "${YELLOW}=========================================${NC}"
echo ""
if [ "$EUID" -ne 0 ]; then 
   echo -e "${RED}ERROR: Run as root${NC}"
   exit 1
fi
echo -e "${YELLOW}[1/10] Stopping services...${NC}"
systemctl stop nginx nagios 2>/dev/null || true
echo -e "${YELLOW}[2/10] Removing default Nginx configs...${NC}"
rm -f /etc/nginx/sites-enabled/default /etc/nginx/sites-available/default
echo -e "${YELLOW}[3/10] Creating Nginx config...${NC}"
tee /etc/nginx/sites-available/nagios > /dev/null << "NGINX"
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    client_max_body_size 50M;
    location / {
        return 403;
    }
    location /nagios/ {
        alias /usr/local/nagios/share/;
        index index.php index.html;
        auth_basic "Nagios Access";
        auth_basic_user_file /usr/local/nagios/etc/htpasswd.users;
        location ~ ^/nagios/.*\.(css|js|png|jpg|jpeg|gif|ico|woff|woff2|ttf|svg|eot)$ {
            alias /usr/local/nagios/share/;
            access_log off;
            expires 30d;
        }
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
echo -e "${YELLOW}[4/10] Enabling config...${NC}"
ln -sf /etc/nginx/sites-available/nagios /etc/nginx/sites-enabled/nagios
echo -e "${YELLOW}[5/10] Testing Nginx...${NC}"
nginx -t
echo -e "${YELLOW}[6/10] Updating hosts config...${NC}"
tee /usr/local/nagios/etc/objects/localhost.cfg > /dev/null << "HOSTS"
define host{
    use                     local-host
    host_name               localhost
    alias                   Nagios Server
    address                 127.0.0.1
}
define host{
    use                     local-host
    host_name               app-server
    alias                   Next.js App
    address                 13.61.174.148
}
define service{
    use                     local-service
    host_name               localhost
    service_description     CPU Load
    check_command           check_local_load!5.0,4.0!10.0,6.0
}
define service{
    use                     local-service
    host_name               localhost
    service_description     Disk Usage
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
    service_description     HTTP
    check_command           check_http!-p 80 -u /
}
define service{
    use                     local-service
    host_name               app-server
    service_description     NRPE
    check_command           check_nrpe!-H 13.61.181.123
}
define service{
    use                     local-service
    host_name               app-server
    service_description     Remote Load
    check_command           check_nrpe!-H 13.61.174.148 -c check_load
}
define service{
    use                     local-service
    host_name               app-server
    service_description     Remote Disk
    check_command           check_nrpe!-H 13.61.174.148 -c check_disk
}
define service{
    use                     local-service
    host_name               app-server
    service_description     Remote Memory
    check_command           check_nrpe!-H 13.61.174.148 -c check_memory
}
define service{
    use                     local-service
    host_name               app-server
    service_description     Remote Processes
    check_command           check_nrpe!-H 13.61.174.148 -c check_processes
}
HOSTS
echo -e "${YELLOW}[7/10] Fixing permissions...${NC}"
chown -R nagios:nagios /usr/local/nagios
chmod 755 /usr/local/nagios/share /usr/local/nagios/sbin
echo -e "${YELLOW}[8/10] Verifying config...${NC}"
/usr/local/nagios/bin/nagios -v /usr/local/nagios/etc/nagios.cfg 2>&1 | tail -3
echo -e "${YELLOW}[9/10] Starting services...${NC}"
systemctl start php-fpm nginx nagios
sleep 2
echo -e "${YELLOW}[10/10] Verifying...${NC}"
echo ""
systemctl is-active nginx > /dev/null && echo -e "${GREEN}✓ Nginx${NC}" || echo -e "${RED}✗ Nginx${NC}"
systemctl is-active nagios > /dev/null && echo -e "${GREEN}✓ Nagios${NC}" || echo -e "${RED}✗ Nagios${NC}"
systemctl is-active php-fpm > /dev/null && echo -e "${GREEN}✓ PHP-FPM${NC}" || echo -e "${RED}✗ PHP-FPM${NC}"
echo ""
echo -e "${GREEN}✅ DONE!${NC}"
echo -e "Access: ${YELLOW}http://16.16.215.8/nagios/${NC}"
echo -e "User: ${YELLOW}nagios${NC} | Pass: ${YELLOW}nagios123${NC}"
echo ""
echo -e "${GREEN}Monitoring:${NC}"
echo -e "  • localhost: 4 services"
echo -e "  • app-server (13.61.174.148): 8 services"
echo ""
'

# Execute the script on remote server via AWS Systems Manager or EC2 Instance Connect
echo "Executing configuration on remote server..."
echo ""

# Try using AWS Systems Manager Session Manager (if available)
if command -v aws &> /dev/null; then
    echo "Using AWS Systems Manager Session Manager..."
    aws ssm start-session --target "i-<instance-id>" --document-name "AWS-StartInteractiveCommand" 2>/dev/null || {
        echo "Session Manager not available, trying SSH..."
    }
fi

# Fallback to SSH with password prompt
echo "Please enter your SSH password when prompted:"
ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "$REMOTE_USER@$REMOTE_IP" "sudo bash << 'SCRIPT'
$REMOTE_SCRIPT
SCRIPT
" || {
    echo ""
    echo "SSH connection failed. Please use AWS Console instead:"
    echo "1. Go to AWS EC2 Console"
    echo "2. Select instance 16.16.215.8"
    echo "3. Click 'Connect' → EC2 Instance Connect"
    echo "4. Paste this entire command:"
    echo ""
    echo "sudo bash << 'SCRIPT'"
    echo "$REMOTE_SCRIPT"
    echo "SCRIPT"
}
