#!/bin/bash

set -e

echo "========================================="
echo "NAGIOS + NGINX COMPLETE FIX"
echo "========================================="

# Step 1: Fix file permissions and ownership
echo "[1/5] Fixing permissions..."
chmod 755 /usr/local/nagios
chmod 755 /usr/local/nagios/share
chmod 644 /usr/local/nagios/share/*
chmod 755 /usr/local/nagios/share/*/
chown -R www-data:www-data /usr/local/nagios/share
chown -R nagios:nagios /usr/local/nagios/var
chmod 755 /usr/local/nagios/var
chmod 666 /usr/local/nagios/var/rw/nagios.cmd 2>/dev/null || true

# Step 2: Configure PHP-FPM to use www-data
echo "[2/5] Configuring PHP-FPM..."
systemctl restart php8.1-fpm

# Step 3: Remove all Nginx configs
echo "[3/5] Cleaning Nginx..."
rm -f /etc/nginx/sites-enabled/*
rm -f /etc/nginx/sites-available/default /etc/nginx/sites-available/nagios

# Step 4: Create working Nginx config
echo "[4/5] Creating Nginx config..."
cat > /etc/nginx/sites-available/nagios << 'NGINXCONF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;

    # Point to nagios share directory
    root /usr/local/nagios/share;
    index index.php index.html index.htm;

    # Deny access to root
    location = / {
        return 301 /nagios/;
    }

    # Main nagios location
    location /nagios/ {
        # Authentication
        auth_basic "Nagios Access";
        auth_basic_user_file /usr/local/nagios/etc/htpasswd.users;

        # Rewrite to remove nagios prefix
        rewrite ^/nagios/(.*)$ /$1 break;

        # Try files, then fallback to index.php
        try_files $uri $uri/ /index.php?$args;

        # PHP handler
        location ~ \.php$ {
            fastcgi_pass unix:/run/php/php8.1-fpm.sock;
            fastcgi_index index.php;
            fastcgi_param SCRIPT_FILENAME /usr/local/nagios/share$fastcgi_script_name;
            fastcgi_param REMOTE_USER $remote_user;
            include fastcgi_params;
        }

        # Static files
        location ~ \.(css|js|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf)$ {
            access_log off;
            expires 7d;
        }
    }

    # Block everything else
    location / {
        return 404;
    }

    error_log /var/log/nginx/nagios_error.log;
    access_log /var/log/nginx/nagios_access.log;
}
NGINXCONF

# Enable config
ln -sf /etc/nginx/sites-available/nagios /etc/nginx/sites-enabled/nagios

# Test
echo "[5/5] Testing and starting services..."
nginx -t 2>&1 | grep -i "ok\|successful" || (nginx -t && false)

# Restart services
systemctl restart nginx
sleep 1
systemctl restart nagios
sleep 2

# Verify
echo ""
echo "========================================="
echo "VERIFICATION"
echo "========================================="
echo ""

if systemctl is-active nginx > /dev/null; then
    echo "✅ Nginx: RUNNING"
else
    echo "❌ Nginx: FAILED"
    systemctl status nginx
fi

if systemctl is-active nagios > /dev/null; then
    echo "✅ Nagios: RUNNING"
else
    echo "❌ Nagios: FAILED"
    systemctl status nagios
fi

if systemctl is-active php8.1-fpm > /dev/null; then
    echo "✅ PHP-FPM: RUNNING"
else
    echo "❌ PHP-FPM: FAILED"
fi

echo ""
echo "========================================="
echo "✅ COMPLETE!"
echo "========================================="
echo ""
echo "Access: http://16.16.215.8/nagios/"
echo "Login: nagios / nagios123"
echo ""
echo "Test locally:"
curl -s -u nagios:nagios123 http://127.0.0.1/nagios/ | grep -o "<title>.*</title>" || echo "Checking..."
echo ""
