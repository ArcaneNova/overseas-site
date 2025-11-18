#!/bin/bash

# Script to fix the SSH key issue
# The new instances (13.235.135.216 and 13.234.114.114) were created but might have wrong keys
# This script will delete old instances and test the new ones

set -e

echo "======================================"
echo "Fixing SSH Key Authentication"
echo "======================================"

# 1. Delete old instances
echo ""
echo "1️⃣  Deleting old EC2 instances..."
aws ec2 terminate-instances \
  --region ap-south-1 \
  --instance-ids $(aws ec2 describe-instances \
    --region ap-south-1 \
    --filters "Name=instance-state-name,Values=running" \
    --query "Reservations[].Instances[?PublicIpAddress=='13.233.112.94' || PublicIpAddress=='13.127.218.112'].InstanceId" \
    --output text) 2>/dev/null || echo "No old instances to terminate"

echo "✅ Termination requested"

# 2. Wait for cleanup
echo ""
echo "2️⃣  Waiting for instances to terminate (20 seconds)..."
sleep 20

# 3. List running instances
echo ""
echo "3️⃣  Active instances:"
aws ec2 describe-instances \
  --region ap-south-1 \
  --filters "Name=instance-state-name,Values=running" \
  --query "Reservations[].Instances[].[PublicIpAddress,State.Name]" \
  --output table

# 4. Check if new instances are accessible
echo ""
echo "4️⃣  Testing SSH to new instances (waiting 60 seconds for full boot)..."
sleep 60

APP_IP="13.235.135.216"
NAGIOS_IP="13.234.114.114"

echo ""
echo "Testing app server ($APP_IP)..."
if ssh -o ConnectTimeout=10 -i ~/.ssh/deploy-key ubuntu@$APP_IP 'echo "✅ App server reachable"' 2>&1; then
  echo "Success!"
else
  echo "⚠️  Still unreachable, might need more time"
fi

echo ""
echo "Testing Nagios server ($NAGIOS_IP)..."
if ssh -o ConnectTimeout=10 -i ~/.ssh/deploy-key ubuntu@$NAGIOS_IP 'echo "✅ Nagios server reachable"' 2>&1; then
  echo "Success!"
else
  echo "⚠️  Still unreachable, might need more time"
fi

echo ""
echo "Done! Try running Ansible again:"
echo "  bash deploy-all.sh"
echo ""
