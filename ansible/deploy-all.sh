#!/bin/bash

set -e

echo "======================================"
echo "Complete Deployment Script"
echo "======================================"

# Get the script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# 0. Wait for instances to be ready
echo ""
echo "0️⃣  Waiting for instances to be ready (30-60 seconds)..."
bash wait-for-instances.sh || {
  echo "⚠️  Instances not ready - trying anyway (they might boot soon)"
}

# 1. Add SSH host keys
echo ""
echo "1️⃣  Adding SSH host keys..."
ssh-keyscan -H 13.61.181.123 >> ~/.ssh/known_hosts 2>/dev/null || true
ssh-keyscan -H 16.16.215.8 >> ~/.ssh/known_hosts 2>/dev/null || true
echo "✅ SSH host keys added"

# 2. Test connectivity
echo ""
echo "2️⃣  Testing Ansible connectivity..."
ansible all -i inventory.ini -m ping

# 3. Deploy app server
echo ""
echo "3️⃣  Deploying app server with Ansible..."
echo "This will take 5-10 minutes..."
ansible-playbook -i inventory.ini playbook.yml -e @vars.yml

# 4. Deploy Nagios server
echo ""
echo "4️⃣  Deploying Nagios server..."
echo "This will take 3-5 minutes..."
ansible-playbook -i inventory.ini nagios-playbook.yml

# 5. Verify deployment
echo ""
echo "5️⃣  Verifying deployment..."
echo ""
echo "App Server Status:"
ssh -i ~/.ssh/deploy-key ubuntu@13.61.181.123 "pm2 status"

echo ""
echo "Nagios Service Status:"
ssh -i ~/.ssh/deploy-key ubuntu@16.16.215.8 "sudo systemctl status nagios --no-pager"

echo ""
echo "======================================"
echo "✅ Deployment Complete!"
echo "======================================"
echo ""
echo "📱 Access Points:"
echo "  - App:    http://13.61.181.123"
echo "  - Nagios: http://16.16.215.8 (username: nagios, password: nagios123)"
echo ""
