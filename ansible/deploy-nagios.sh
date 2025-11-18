#!/bin/bash

set -e

echo "======================================"
echo "Step 2: Deploy Nagios Server"
echo "======================================"

cd "$(dirname "$0")"

# Add SSH host keys
echo ""
echo "📍 Adding SSH host keys..."
ssh-keyscan -H 13.48.24.241 >> ~/.ssh/known_hosts 2>/dev/null || true
echo "✅ Done"

# Test connectivity
echo ""
echo "📍 Testing connectivity to Nagios server..."
ansible 13.48.24.241 -i inventory.ini -m ping

# Deploy
echo ""
echo "📍 Deploying Nagios server (this takes 3-5 minutes)..."
ansible-playbook -i inventory.ini nagios-playbook.yml

echo ""
echo "======================================"
echo "✅ Nagios Server Deployment Complete!"
echo "======================================"
echo ""
echo "Check Nagios service:"
echo "ssh -i ~/.ssh/deploy-key ubuntu@13.48.24.241 sudo systemctl status nagios"
echo ""
echo "Access Nagios:"
echo "http://13.48.24.241"
echo "Username: nagios"
echo "Password: nagios123"
echo ""
