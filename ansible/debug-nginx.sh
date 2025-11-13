#!/bin/bash
# Debug and fix Nginx issue

echo "=== Checking PM2 Status ==="
ssh -i ~/.ssh/deploy-key ubuntu@13.127.218.112 "pm2 status"

echo ""
echo "=== Testing Local Connectivity (localhost:3000) ==="
ssh -i ~/.ssh/deploy-key ubuntu@13.127.218.112 "curl -s http://localhost:3000 | head -30"

echo ""
echo "=== Checking Nginx Configuration ==="
ssh -i ~/.ssh/deploy-key ubuntu@13.127.218.112 "sudo nginx -T 2>&1 | head -20"

echo ""
echo "=== Nginx Status ==="
ssh -i ~/.ssh/deploy-key ubuntu@13.127.218.112 "sudo systemctl status nginx"

echo ""
echo "=== Restarting Nginx ==="
ssh -i ~/.ssh/deploy-key ubuntu@13.127.218.112 "sudo systemctl restart nginx && echo 'Nginx restarted successfully'"

echo ""
echo "=== Waiting 3 seconds... ==="
sleep 3

echo ""
echo "=== Testing via Public IP ==="
curl -s http://13.127.218.112 | head -30
