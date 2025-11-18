#!/bin/bash

# Complete deployment fix script
# This will recreate AWS infrastructure and deploy properly

set -e

echo "======================================"
echo "Complete Fresh Deployment"
echo "======================================"

cd "$(dirname "$0")/../.."

# 1. Destroy old infrastructure
echo ""
echo "1️⃣  Destroying old AWS infrastructure..."
cd terraform
terraform destroy -auto-approve
sleep 10

# 2. Re-init and apply Terraform
echo ""
echo "2️⃣  Creating new AWS infrastructure..."
terraform init
terraform plan -out=tfplan
terraform apply tfplan

# Get new IPs
echo ""
echo "3️⃣  Retrieving new IPs..."
APP_PUBLIC=$(terraform output -raw app_public_ip)
APP_PRIVATE=$(terraform output -raw app_private_ip)
NAGIOS_PUBLIC=$(terraform output -raw nagios_public_ip)
NAGIOS_PRIVATE=$(terraform output -raw nagios_private_ip)

echo "New Infrastructure Created:"
echo "  App Server: $APP_PUBLIC (private: $APP_PRIVATE)"
echo "  Nagios Server: $NAGIOS_PUBLIC (private: $NAGIOS_PRIVATE)"

# 3. Update inventory
cd ../ansible

echo ""
echo "4️⃣  Updating Ansible inventory..."
cat > inventory.ini << EOF
[app]
$APP_PUBLIC ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/deploy-key ansible_host=$APP_PUBLIC private_ip=$APP_PRIVATE

[nagios]
$NAGIOS_PUBLIC ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/deploy-key ansible_host=$NAGIOS_PUBLIC private_ip=$NAGIOS_PRIVATE

[all:vars]
ansible_python_interpreter=/usr/bin/python3
EOF

echo "✅ Inventory updated"

# 4. Add SSH host keys
echo ""
echo "5️⃣  Adding SSH host keys..."
ssh-keyscan -H $APP_PUBLIC >> ~/.ssh/known_hosts 2>/dev/null || true
ssh-keyscan -H $NAGIOS_PUBLIC >> ~/.ssh/known_hosts 2>/dev/null || true

# 5. Wait for instances to be ready
echo ""
echo "6️⃣  Waiting for instances to boot (30 seconds)..."
sleep 30

# 6. Test connectivity
echo ""
echo "7️⃣  Testing connectivity..."
ansible all -i inventory.ini -m ping

# 7. Deploy app
echo ""
echo "8️⃣  Deploying app server (5-10 minutes)..."
ansible-playbook -i inventory.ini playbook.yml -e @vars.yml

# 8. Deploy Nagios
echo ""
echo "9️⃣  Deploying Nagios server (3-5 minutes)..."
ansible-playbook -i inventory.ini nagios-playbook.yml

echo ""
echo "======================================"
echo "✅ Complete Fresh Deployment Done!"
echo "======================================"
echo ""
echo "Access:"
echo "  📱 App: http://$APP_PUBLIC"
echo "  📊 Nagios: http://$NAGIOS_PUBLIC (nagios/nagios123)"
echo ""
