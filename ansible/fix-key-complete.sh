#!/bin/bash

# Direct SSH key fix using AWS CLI
# This creates a completely new key pair and sets up infrastructure correctly

set -e

echo "======================================"
echo "SSH Key Fix - Direct Method"
echo "======================================"

cd ~/.ssh

# 1. Generate NEW key pair (completely fresh)
echo ""
echo "1️⃣  Creating new SSH key pair..."
ssh-keygen -t rsa -b 4096 -f deploy-key-new -N "" -C "deploy@overseas-site"

# 2. Get new public key in proper format
PUBLIC_KEY_CONTENT=$(cat deploy-key-new.pub | awk '{print $2}')

# 3. Delete old key from AWS
echo ""
echo "2️⃣  Deleting old key from AWS..."
aws ec2 delete-key-pair --region ap-south-1 --key-name deploy-key || echo "   (old key deleted or didn't exist)"

sleep 2

# 4. Create new key pair in AWS
echo ""
echo "3️⃣  Creating new key pair in AWS..."
aws ec2 create-key-pair \
  --region ap-south-1 \
  --key-name deploy-key \
  > /tmp/deploy-key-aws.json

echo "✅ New key created in AWS"

# 5. Replace local key with new one
echo ""
echo "4️⃣  Updating local key files..."
mv deploy-key deploy-key-old 2>/dev/null || true
mv deploy-key.pub deploy-key-old.pub 2>/dev/null || true
mv deploy-key-new deploy-key
mv deploy-key-new.pub deploy-key.pub
chmod 600 deploy-key
chmod 644 deploy-key.pub

echo "✅ Local keys updated"

# 6. Terminate old instances and destroy infrastructure
echo ""
echo "5️⃣  Destroying old infrastructure..."
cd ~/overseas-site/terraform

# Get all instance IDs and terminate them
aws ec2 terminate-instances --region ap-south-1 \
  --instance-ids $(aws ec2 describe-instances \
    --region ap-south-1 \
    --filters "Name=instance-state-name,Values=running,stopped" \
    --query "Reservations[].Instances[].InstanceId" \
    --output text) \
  2>/dev/null || echo "   (no instances to terminate)"

echo "   - Waiting 15 seconds for termination..."
sleep 15

# Clean terraform state
echo "   - Cleaning Terraform state..."
rm -f terraform.tfstate terraform.tfstate.backup .terraform.lock.hcl 2>/dev/null || true

# 7. Recreate infrastructure
echo ""
echo "6️⃣  Creating fresh AWS infrastructure..."
terraform init -upgrade
terraform apply -auto-approve

# Get new IPs
sleep 10
APP_IP=$(terraform output -raw app_public_ip)
NAGIOS_IP=$(terraform output -raw nagios_public_ip)
APP_PRIVATE=$(terraform output -raw app_private_ip)
NAGIOS_PRIVATE=$(terraform output -raw nagios_private_ip)

echo ""
echo "✅ New infrastructure ready:"
echo "   - App: $APP_IP (private: $APP_PRIVATE)"
echo "   - Nagios: $NAGIOS_IP (private: $NAGIOS_PRIVATE)"

# 8. Update inventory
echo ""
echo "7️⃣  Updating Ansible inventory..."
cd ../ansible

cat > inventory.ini << EOF
[app]
$APP_IP ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/deploy-key ansible_host=$APP_IP private_ip=$APP_PRIVATE

[nagios]
$NAGIOS_IP ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/deploy-key ansible_host=$NAGIOS_IP private_ip=$NAGIOS_PRIVATE

[all:vars]
ansible_python_interpreter=/usr/bin/python3
EOF

echo "✅ Inventory updated"

# 9. Add SSH host keys
echo ""
echo "8️⃣  Adding SSH host keys..."
rm -f ~/.ssh/known_hosts
ssh-keyscan -H $APP_IP >> ~/.ssh/known_hosts 2>/dev/null || true
ssh-keyscan -H $NAGIOS_IP >> ~/.ssh/known_hosts 2>/dev/null || true

echo "✅ Host keys added"

# 10. Wait for instances to fully boot
echo ""
echo "9️⃣  Waiting 60 seconds for instances to fully boot..."
sleep 60

# 11. Test connectivity
echo ""
echo "🔟  Testing Ansible connectivity..."
if ! ansible all -i inventory.ini -m ping; then
  echo ""
  echo "⚠️  Connectivity test failed. Waiting 30 more seconds..."
  sleep 30
  echo "Retrying..."
  ansible all -i inventory.ini -m ping
fi

echo ""
echo "======================================"
echo "✅ SSH Key Fix Complete!"
echo "======================================"
echo ""
echo "New Infrastructure:"
echo "  📱 App: http://$APP_IP"
echo "  📊 Nagios: http://$NAGIOS_IP"
echo ""
echo "Next step:"
echo "  cd ~/overseas-site/ansible"
echo "  bash deploy-all.sh"
echo ""
