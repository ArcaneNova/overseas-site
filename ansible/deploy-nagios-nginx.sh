#!/bin/bash

set -e

echo "========================================="
echo "NAGIOS NGINX DEPLOYMENT"
echo "========================================="

ssh -i ~/.ssh/deploy-key-old ubuntu@16.16.215.8 << 'ENDSSH'

set -e

echo "[1/8] Stopping Apache..."
sudo systemctl stop apache2 2>/dev/null || true
sudo systemctl disable apache2 2>/dev/null || true

echo "[2/8] Installing Nginx..."
sudo apt-get update -qq
sudo apt-get install -y nginx php-fpm > /dev/null 2>&1

echo "[3/8] Configuring PHP-FPM..."
sudo systemctl start php8.1-fpm
sudo systemctl enable php8.1-fpm

echo "[4/8] Creating Nginx Nagios config..."
sudo bash << 'NGINX'
cat > /etc/nginx/sites-available/nagios << 'CONF'
server {
    listen 80 default_server;
    server_name _;
    
    location / {
        return 403;
    }
    
    location /nagios/ {
        alias /usr/local/nagios/share/;
        index index.php index.html;
        
        auth_basic "Nagios";
        auth_basic_user_file /usr/local/nagios/etc/htpasswd.users;
        
        location ~ \.php$ {
            fastcgi_pass unix:/run/php/php8.1-fpm.sock;
            fastcgi_index index.php;
            fastcgi_param SCRIPT_FILENAME /usr/local/nagios/share$fastcgi_script_name;
            include fastcgi_params;
        }
        
        location ~ \.(css|js|png|jpg|gif|ico)$ {
            access_log off;
        }
    }
    
    error_log /var/log/nginx/nagios_error.log;
    access_log /var/log/nginx/nagios_access.log;
}
CONF

sudo rm -f /etc/nginx/sites-enabled/default
sudo ln -sf /etc/nginx/sites-available/nagios /etc/nginx/sites-enabled/nagios
NGINX

echo "[5/8] Installing fcgiwrap for CGI..."
sudo apt-get install -y fcgiwrap > /dev/null 2>&1
sudo systemctl start fcgiwrap
sudo systemctl enable fcgiwrap

echo "[6/8] Testing Nginx config..."
sudo nginx -t

echo "[7/8] Starting Nginx..."
sudo systemctl start nginx
sudo systemctl enable nginx
sleep 2

echo "[8/8] Restarting Nagios..."
sudo systemctl restart nagios
sleep 2

echo ""
echo "========================================="
echo "✅ NAGIOS NGINX DEPLOYMENT COMPLETE!"
echo "========================================="
echo ""
echo "Access Nagios:"
echo "  URL: http://16.16.215.8/nagios"
echo "  Username: nagios"
echo "  Password: nagios123"
echo ""
echo "Service Status:"
echo "  Nginx: $(sudo systemctl is-active nginx)"
echo "  Nagios: $(sudo systemctl is-active nagios)"
echo "  PHP-FPM: $(sudo systemctl is-active php8.1-fpm)"
echo ""

ENDSSH

echo "✅ Deployment complete!"
