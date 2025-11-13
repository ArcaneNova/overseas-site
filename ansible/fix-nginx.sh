#!/bin/bash
# Quick fix for Nginx reverse proxy

echo "🔧 Fixing Nginx Reverse Proxy Configuration..."

# SSH into app server and fix nginx
ssh -i ~/.ssh/deploy-key ubuntu@13.127.218.112 << 'EOF'

echo "Checking PM2 status..."
pm2 status

echo ""
echo "Testing Next.js locally on port 3000..."
curl -s http://localhost:3000 | head -20 || echo "App not responding yet, waiting..."

echo ""
echo "Checking Nginx default site..."
if [ -L /etc/nginx/sites-enabled/default ]; then
    echo "⚠️  Default site still linked, removing..."
    sudo rm -f /etc/nginx/sites-enabled/default
fi

echo ""
echo "Checking nextjs site config..."
if [ ! -f /etc/nginx/sites-available/nextjs ]; then
    echo "❌ nextjs config missing! Creating..."
    sudo tee /etc/nginx/sites-available/nextjs > /dev/null << 'NGINX'
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
NGINX
fi

if [ ! -L /etc/nginx/sites-enabled/nextjs ]; then
    echo "Creating symlink for nextjs site..."
    sudo ln -sf /etc/nginx/sites-available/nextjs /etc/nginx/sites-enabled/nextjs
fi

echo ""
echo "Testing Nginx configuration..."
sudo nginx -t

echo ""
echo "Restarting Nginx..."
sudo systemctl restart nginx

echo "✅ Done!"

EOF

echo ""
echo "🌐 Testing from outside..."
sleep 2
curl -s http://13.127.218.112 | head -30
