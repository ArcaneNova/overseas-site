#!/bin/bash

echo "========================================"
echo "Infrastructure Diagnostic"
echo "========================================"
echo ""

# Check if AWS CLI is available
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI is not installed or not in PATH"
    echo "   Install with: sudo apt-get update && sudo apt-get install -y awscli"
    exit 1
fi

echo "✅ AWS CLI found"
echo ""

# Check AWS credentials
echo "📍 Checking AWS credentials..."
if aws sts get-caller-identity &>/dev/null; then
    echo "✅ AWS credentials configured"
    echo "   $(aws sts get-caller-identity)"
else
    echo "❌ AWS credentials not configured"
    echo "   Run: aws configure"
    exit 1
fi

echo ""

# Check instances in eu-north-1
echo "📍 Checking EC2 instances in eu-north-1..."
INSTANCES=$(aws ec2 describe-instances --region eu-north-1 --query 'Reservations[*].Instances[*].[InstanceId,InstanceType,State.Name,PublicIpAddress,PrivateIpAddress,Tags[?Key==`Name`].Value|[0]]' --output text)

if [ -z "$INSTANCES" ]; then
    echo "❌ No instances found in eu-north-1"
else
    echo "✅ Found instances:"
    echo "$INSTANCES"
fi

echo ""

# Check Terraform state
echo "📍 Checking Terraform state..."
if [ -f "terraform.tfstate" ]; then
    echo "✅ Terraform state file exists"
    
    # Extract IPs from state
    APP_IP=$(grep -o '"public_ip":"[^"]*"' terraform.tfstate | head -1 | cut -d'"' -f4)
    NAGIOS_IP=$(grep -o '"public_ip":"[^"]*"' terraform.tfstate | tail -1 | cut -d'"' -f4)
    
    echo "   App IP: $APP_IP"
    echo "   Nagios IP: $NAGIOS_IP"
else
    echo "❌ No Terraform state file found"
    echo "   Run: terraform init && terraform apply"
fi

echo ""
echo "========================================"
echo "End of Diagnostic"
echo "========================================"
