#!/bin/bash

# This script fixes the SSH key mismatch issue

set -e

echo "======================================"
echo "SSH Key Mismatch Fix"
echo "======================================"

cd ~/.ssh

# 1. Check current key fingerprint in AWS
echo ""
echo "1️⃣  Current SSH key fingerprint:"
ssh-keygen -lf deploy-key

echo ""
echo "2️⃣  AWS deploy-key fingerprint:"
aws ec2 describe-key-pairs --region ap-south-1 --key-names deploy-key --output table

# 3. The problem: The key in AWS doesn't match the local one
# Solution: Re-import the key
echo ""
echo "3️⃣  Solution: Re-importing SSH key to AWS..."

# Delete old key from AWS
echo "   - Deleting old key from AWS..."
aws ec2 delete-key-pair --region ap-south-1 --key-name deploy-key || echo "   (key might already be gone)"

sleep 2

# Get public key
PUBLIC_KEY=$(cat deploy-key.pub)

# Import the key to AWS
echo "   - Importing new key..."
aws ec2 import-key-pair \
  --region ap-south-1 \
  --key-name deploy-key \
  --public-key-material "$PUBLIC_KEY"

echo "✅ Key re-imported to AWS"

# 4. Now terminate old instances and recreate
echo ""
echo "4️⃣  Cleaning up old instances..."
cd ~/overseas-site/terraform

# Destroy infrastructure (it will try to use the imported key)
echo "   - Running terraform destroy..."
terraform destroy -auto-approve || echo "   (some resources might not exist)"

sleep 10

# Apply fresh infrastructure with the correct key
echo "   - Running terraform apply..."
terraform apply -auto-approve

# Get new IPs
APP_IP=$(terraform output -raw app_public_ip)
NAGIOS_IP=$(terraform output -raw nagios_public_ip)
APP_PRIVATE=$(terraform output -raw app_private_ip)
NAGIOS_PRIVATE=$(terraform output -raw nagios_private_ip)

echo ""
echo "5️⃣  New infrastructure created:"
echo "   - App: $APP_IP (private: $APP_PRIVATE)"
echo "   - Nagios: $NAGIOS_IP (private: $NAGIOS_PRIVATE)"

# Update inventory
echo ""
echo "6️⃣  Updating inventory..."
cd ../ansible

cat > inventory.ini << EOF
[app]
$APP_IP ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/deploy-key ansible_host=$APP_IP private_ip=$APP_PRIVATE

[nagios]
$NAGIOS_IP ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/deploy-key ansible_host=$NAGIOS_IP private_ip=$NAGIOS_PRIVATE

[all:vars]
ansible_python_interpreter=/usr/bin/python3
EOF

# Add host keys
ssh-keyscan -H $APP_IP >> ~/.ssh/known_hosts 2>/dev/null || true
ssh-keyscan -H $NAGIOS_IP >> ~/.ssh/known_hosts 2>/dev/null || true

echo "✅ Inventory updated"

# Wait for instances
echo ""
echo "7️⃣  Waiting 45 seconds for instances to boot fully..."
sleep 45

# Test
echo ""
echo "8️⃣  Testing connectivity..."
ansible all -i inventory.ini -m ping

echo ""
echo "✅ SSH authentication fixed!"
echo ""
echo "Next: Run  bash deploy-all.sh  to deploy the application"
echo ""
