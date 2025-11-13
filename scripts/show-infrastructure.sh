#!/usr/bin/env bash

# Script to get infrastructure information
# Shows load balancer DNS, instance IPs, monitoring access

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR/infrastructure/terraform"

echo "=========================================="
echo "BnOverseas Infrastructure Status"
echo "=========================================="
echo ""

# Check if terraform state exists
if [ ! -f "terraform.tfstate" ]; then
    echo "No Terraform state found. Have you deployed yet?"
    exit 1
fi

echo "Infrastructure Outputs:"
echo "-----------------------"
terraform output -json | jq '.'

echo ""
echo "=========================================="
echo "Access Information"
echo "=========================================="

LB_DNS=$(terraform output -raw load_balancer_dns 2>/dev/null || echo "Not available")
MON_IP=$(terraform output -raw monitoring_instance_public_ip 2>/dev/null || echo "Not available")
ASG_NAME=$(terraform output -raw autoscaling_group_name 2>/dev/null)

echo "Application URL: http://$LB_DNS"
echo "Nagios Dashboard: http://$MON_IP/nagios4"
echo ""
echo "Nagios Credentials:"
echo "  Username: nagiosadmin"
echo "  Password: admin123"
echo ""
echo "Auto-Scaling Group: $ASG_NAME"

# Get running instances
echo ""
echo "Running Instances:"
echo "-------------------"
aws ec2 describe-instances \
    --filters "Name=tag:Environment,Values=prod" "Name=instance-state-name,Values=running" \
    --query 'Reservations[*].Instances[*].[InstanceId,PrivateIpAddress,PublicIpAddress,Tags[?Key==`Name`].Value|[0]]' \
    --output table

echo ""
echo "=========================================="
