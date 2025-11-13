#!/bin/bash
# Accept SSH host keys for Ansible hosts

echo "Adding EC2 instance host keys to known_hosts..."

# Add app server
echo "Adding 13.127.218.112..."
ssh-keyscan -H 13.127.218.112 >> ~/.ssh/known_hosts 2>/dev/null

# Add nagios server
echo "Adding 13.233.112.94..."
ssh-keyscan -H 13.233.112.94 >> ~/.ssh/known_hosts 2>/dev/null

echo "✅ Host keys added successfully!"
echo ""
echo "Testing SSH connectivity..."
ssh -i ~/.ssh/deploy-key -o ConnectTimeout=5 ubuntu@13.127.218.112 "echo 'App server: OK'" || echo "⚠️ App server not ready yet (wait a few seconds for instance boot)"
ssh -i ~/.ssh/deploy-key -o ConnectTimeout=5 ubuntu@13.233.112.94 "echo 'Nagios server: OK'" || echo "⚠️ Nagios server not ready yet (wait a few seconds for instance boot)"

echo ""
echo "You can now run: ansible all -i inventory.ini -m ping"
