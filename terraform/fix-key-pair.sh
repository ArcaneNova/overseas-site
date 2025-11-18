#!/bin/bash

set -e

echo "========================================"
echo "Fix Terraform - Duplicate Key Pair"
echo "========================================"
echo ""

cd "$(dirname "$0")"

# Solution 1: Remove the key pair from Terraform state and recreate
echo "🔧 Fixing Terraform state..."
echo ""

# Remove from state
terraform state rm aws_key_pair.deploy_key 2>/dev/null || echo "✅ Key pair not in state (good)"

echo "✅ Removed from Terraform state"
echo ""

# Now try to apply again
echo "📍 Running terraform apply again..."
terraform apply -auto-approve

echo ""
echo "========================================"
echo "✅ Fixed!"
echo "========================================"
echo ""
