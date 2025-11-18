#!/bin/bash

set -e

echo "========================================"
echo "Waiting for Instances to be Ready"
echo "========================================"

# Get IPs from inventory
APP_IP="13.61.181.123"
NAGIOS_IP="16.16.215.8"

echo ""
echo "📍 Waiting for SSH access on both instances..."
echo "This may take 30-60 seconds..."
echo ""

# Wait for app server
echo "⏳ App server: $APP_IP"
for i in {1..60}; do
  if nc -z -w 1 $APP_IP 22 2>/dev/null; then
    echo "✅ App server SSH ready!"
    break
  fi
  echo -n "."
  sleep 1
  if [ $i -eq 60 ]; then
    echo ""
    echo "❌ Timeout waiting for app server SSH"
    exit 1
  fi
done

echo ""

# Wait for Nagios server
echo "⏳ Nagios server: $NAGIOS_IP"
for i in {1..60}; do
  if nc -z -w 1 $NAGIOS_IP 22 2>/dev/null; then
    echo "✅ Nagios server SSH ready!"
    break
  fi
  echo -n "."
  sleep 1
  if [ $i -eq 60 ]; then
    echo ""
    echo "❌ Timeout waiting for Nagios server SSH"
    exit 1
  fi
done

echo ""
echo "========================================"
echo "✅ All instances are ready!"
echo "========================================"
echo ""
echo "You can now run:"
echo "  ansible-playbook -i inventory.ini playbook.yml -e @vars.yml"
echo ""
