#!/bin/bash

set -e

# Direct deployment script - run this directly on the Nagios server
# Usage: sudo bash deploy-direct.sh

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=========================================${NC}"
echo -e "${YELLOW}NAGIOS + NGINX FRESH SETUP${NC}"
echo -e "${YELLOW}=========================================${NC}"
echo ""

if [ "$EUID" -ne 0 ]; then 
   echo -e "${RED}ERROR: This script must be run as root${NC}"
   exit 1
fi

echo -e "${YELLOW}[1/15] Stopping all services...${NC}"
systemctl stop nginx apache2 nagios nrpe php-fpm php8.1-fpm 2>/dev/null || true
systemctl disable nginx apache2 nagios nrpe php-fpm php8.1-fpm 2>/dev/null || true
killall -9 nginx apache2 nagios nrpe php-fpm 2>/dev/null || true

echo -e "${YELLOW}[2/15] Purging old installations...${NC}"
apt-get purge -y nginx apache2 apache2-data nagios nagios-core nagios-common nagios-plugins php php-fpm php8.1-fpm 2>/dev/null || true
apt-get autoremove -y > /dev/null 2>&1
rm -rf /etc/nginx /etc/apache2 /usr/local/nagios /etc/nagios* /var/lib/nagios* /var/cache/nagios* /usr/lib/nagios /etc/nrpe* 2>/dev/null || true

echo -e "${YELLOW}[3/15] Updating system...${NC}"
apt-get update -qq
apt-get upgrade -y > /dev/null 2>&1

echo -e "${YELLOW}[4/15] Installing dependencies...${NC}"
apt-get install -y build-essential libgd-dev libssl-dev libmcrypt-dev unzip wget curl nginx php php-fpm php-gd php-cli fcgiwrap mailutils apache2-utils > /dev/null 2>&1

echo -e "${YELLOW}[5/15] Creating nagios user...${NC}"
useradd -r -M -s /bin/false nagios 2>/dev/null || true
usermod -aG www-data nagios 2>/dev/null || true
usermod -aG nagios www-data 2>/dev/null || true

echo -e "${YELLOW}[6/15] Downloading Nagios...${NC}"
cd /tmp
rm -rf nagios-4.4.13*
wget -q https://github.com/NagiosEnterprises/nagioscore/releases/download/nagios-4.4.13/nagios-4.4.13.tar.gz
tar xzf nagios-4.4.13.tar.gz
cd nagios-4.4.13

echo -e "${YELLOW}[7/15] Compiling Nagios...${NC}"
./configure --prefix=/usr/local/nagios --exec-prefix=/usr/local/nagios --libexecdir=/usr/local/nagios/libexec --with-cgiurl=/nagios/cgi-bin --with-htmurl=/nagios --with-nagios-user=nagios --with-nagios-group=nagios --with-command-user=nagios --with-command-group=nagios --enable-event-broker > /dev/null 2>&1
make all > /dev/null 2>&1
make install > /dev/null 2>&1
make install-init > /dev/null 2>&1
make install-commandmode > /dev/null 2>&1
make install-config > /dev/null 2>&1

echo -e "${YELLOW}[8/15] Installing Nagios Plugins...${NC}"
cd /tmp
rm -rf nagios-plugins-2.3.3*
wget -q https://github.com/nagios-plugins/nagios-plugins/releases/download/release-2.3.3/nagios-plugins-2.3.3.tar.gz
tar xzf nagios-plugins-2.3.3.tar.gz
cd nagios-plugins-2.3.3
./configure --prefix=/usr/local/nagios --exec-prefix=/usr/local/nagios --libexecdir=/usr/local/nagios/libexec --with-nagios-user=nagios --with-nagios-group=nagios > /dev/null 2>&1
make > /dev/null 2>&1
make install > /dev/null 2>&1

echo -e "${YELLOW}[9/15] Installing NRPE...${NC}"
cd /tmp
rm -rf nrpe-3.2.1*
wget -q https://github.com/NagiosEnterprises/nrpe/releases/download/nrpe-3.2.1/nrpe-3.2.1.tar.gz
tar xzf nrpe-3.2.1.tar.gz
cd nrpe-3.2.1
./configure --prefix=/usr/local/nagios > /dev/null 2>&1
make nrpe > /dev/null 2>&1
make install-daemon > /dev/null 2>&1

tee /etc/systemd/system/nrpe.service > /dev/null << 'NRPE'
[Unit]
Description=Nagios Remote Plugin Executor
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/nagios/bin/nrpe -c /usr/local/nagios/etc/nrpe.cfg -f
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
NRPE

systemctl daemon-reload

echo -e "${YELLOW}[10/15] Configuring Nagios...${NC}"
chown -R nagios:nagios /usr/local/nagios

tee /usr/local/nagios/etc/objects/localhost.cfg > /dev/null << 'HOSTS'
define host{
    use                     local-host
    host_name               localhost
    alias                   Nagios Server
    address                 127.0.0.1
}

define host{
    use                     local-host
    host_name               nextjs-app
    alias                   Next.js Application Server
    address                 10.0.1.167
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
    host_name               nextjs-app
    service_description     Ping
    check_command           check_ping!100.0,20%!500.0,60%
}

define service{
    use                     local-service
    host_name               nextjs-app
    service_description     HTTP
    check_command           check_http!-p 80 -u /
}

define service{
    use                     local-service
    host_name               nextjs-app
    service_description     SSH
    check_command           check_tcp!-p 22
}

define service{
    use                     local-service
    host_name               nextjs-app
    service_description     NRPE Agent
    check_command           check_nrpe!-H 10.0.1.167
}

define service{
    use                     local-service
    host_name               nextjs-app
    service_description     System Load
    check_command           check_nrpe!-H 10.0.1.167 -c check_load
}

define service{
    use                     local-service
    host_name               nextjs-app
    service_description     Disk Free
    check_command           check_nrpe!-H 10.0.1.167 -c check_disk
}

define service{
    use                     local-service
    host_name               nextjs-app
    service_description     Memory Usage
    check_command           check_nrpe!-H 10.0.1.167 -c check_memory
}

define service{
    use                     local-service
    host_name               nextjs-app
    service_description     Process Count
    check_command           check_nrpe!-H 10.0.1.167 -c check_processes
}
HOSTS

echo -e "${YELLOW}[11/15] Setting up authentication...${NC}"
htpasswd -bc /usr/local/nagios/etc/htpasswd.users nagios nagios123 > /dev/null 2>&1
chown nagios:nagios /usr/local/nagios/etc/htpasswd.users
chmod 640 /usr/local/nagios/etc/htpasswd.users

echo -e "${YELLOW}[12/15] Configuring Nginx...${NC}"
rm -rf /etc/nginx/sites-available/* /etc/nginx/sites-enabled/*

tee /etc/nginx/sites-available/nagios > /dev/null << 'NGINX'
server {
    listen 80 default_server;
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

        location ~ \.(css|js|png|jpg|jpeg|gif|ico|woff|woff2|ttf|svg)$ {
            alias /usr/local/nagios/share/;
            access_log off;
            expires 30d;
        }

        location ~ \.php$ {
            fastcgi_pass unix:/run/php/php-fpm.sock;
            fastcgi_index index.php;
            fastcgi_param SCRIPT_FILENAME /usr/local/nagios/share$fastcgi_script_name;
            fastcgi_param REMOTE_USER $remote_user;
            include fastcgi_params;
        }
    }

    error_log /var/log/nginx/nagios_error.log;
    access_log /var/log/nginx/nagios_access.log;
}
NGINX

ln -sf /etc/nginx/sites-available/nagios /etc/nginx/sites-enabled/nagios

echo -e "${YELLOW}[13/15] Starting PHP-FPM...${NC}"
systemctl enable php-fpm
systemctl start php-fpm
sleep 2

echo -e "${YELLOW}[14/15] Starting Nginx...${NC}"
nginx -t > /dev/null 2>&1
systemctl enable nginx
systemctl start nginx
sleep 2

echo -e "${YELLOW}[15/15] Starting Nagios...${NC}"
systemctl enable nagios
systemctl start nagios
systemctl enable nrpe
systemctl start nrpe
sleep 2

echo ""
echo -e "${GREEN}✅ SERVICE STATUS:${NC}"
systemctl is-active nginx > /dev/null && echo -e "${GREEN}  ✓ Nginx${NC}" || echo -e "${RED}  ✗ Nginx${NC}"
systemctl is-active nagios > /dev/null && echo -e "${GREEN}  ✓ Nagios${NC}" || echo -e "${RED}  ✗ Nagios${NC}"
systemctl is-active php-fpm > /dev/null && echo -e "${GREEN}  ✓ PHP-FPM${NC}" || echo -e "${RED}  ✗ PHP-FPM${NC}"
systemctl is-active nrpe > /dev/null && echo -e "${GREEN}  ✓ NRPE${NC}" || echo -e "${RED}  ✗ NRPE${NC}"

echo ""
echo -e "${GREEN}✅ INSTALLATION COMPLETE!${NC}"
echo ""
echo -e "${GREEN}Access Nagios at:${NC}"
echo -e "  ${YELLOW}http://16.16.215.8/nagios/${NC}"
echo -e "  User: ${YELLOW}nagios${NC}"
echo -e "  Pass: ${YELLOW}nagios123${NC}"
echo ""
echo -e "${GREEN}Hosts Configured:${NC}"
echo -e "  • localhost (Nagios Server)"
echo -e "  • nextjs-app (10.0.1.167)"
echo ""
echo -e "${GREEN}Services:${NC}"
echo -e "  • 4 services on localhost"
echo -e "  • 8 services on nextjs-app"
echo -e "  • Total: 12 services${NC}"
echo ""
