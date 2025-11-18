#!/bin/bash

set -e

echo "========================================"
echo "Destroy AWS Infrastructure"
echo "========================================"
echo ""
echo "⚠️  WARNING: This will DELETE:"
echo "    - All EC2 instances"
echo "    - VPC and subnets"
echo "    - Security groups"
echo "    - Internet gateways"
echo "    - SSH key pairs"
echo ""
read -p "Are you absolutely sure? Type 'yes' to destroy: " confirm

if [ "$confirm" != "yes" ]; then
    echo "❌ Cancelled - nothing destroyed"
    exit 0
fi

echo ""
echo "🗑️  Destroying infrastructure with Terraform..."
echo ""

cd "$(dirname "$0")/../terraform"

# Run terraform destroy
terraform destroy -auto-approve

echo ""
echo "========================================"
echo "✅ Infrastructure Destroyed!"
echo "========================================"
echo ""
echo "All AWS resources have been removed."
echo ""
echo "To recreate infrastructure:"
echo "1. terraform apply"
echo "2. cd ../ansible"
echo "3. bash deploy-all.sh"
echo ""
