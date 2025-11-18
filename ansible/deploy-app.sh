#!/bin/bash

set -e

echo "======================================"
echo "Step 1: Deploy App Server"
echo "======================================"

cd "$(dirname "$0")"

# Add SSH host keys
echo ""
echo "📍 Adding SSH host keys..."
ssh-keyscan -H 13.61.181.123 >> ~/.ssh/known_hosts 2>/dev/null || true
echo "✅ Done"

# Test connectivity
echo ""
echo "📍 Testing connectivity to app server..."
ansible 13.61.181.123 -i inventory.ini -m ping

# Deploy
echo ""
echo "📍 Deploying Next.js app (this takes 5-10 minutes)..."
ansible-playbook -i inventory.ini playbook.yml -e @vars.yml

echo ""
echo "======================================"
echo "✅ App Server Deployment Complete!"
echo "======================================"
echo ""
echo "Check PM2 status:"
echo "ssh -i ~/.ssh/deploy-key ubuntu@13.61.181.123 pm2 status"
echo ""
echo "View app:"
echo "http://13.235.135.216"
echo ""
