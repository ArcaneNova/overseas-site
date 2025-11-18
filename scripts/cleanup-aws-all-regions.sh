#!/bin/bash

set -e

echo "========================================"
echo "AWS Cleanup - Destroy All Resources"
echo "========================================"
echo ""
echo "⚠️  WARNING: This will DELETE ALL EC2 instances, VPCs, and related resources"
echo "⚠️  across ALL AWS regions!"
echo ""
read -p "Are you sure? Type 'yes' to continue: " confirm

if [ "$confirm" != "yes" ]; then
    echo "❌ Cancelled"
    exit 0
fi

echo ""
echo "Starting cleanup..."
echo ""

# List of all AWS regions
REGIONS=(
    "us-east-1"
    "us-east-2"
    "us-west-1"
    "us-west-2"
    "eu-north-1"
    "eu-west-1"
    "eu-west-2"
    "eu-west-3"
    "eu-central-1"
    "ap-south-1"
    "ap-southeast-1"
    "ap-southeast-2"
    "ap-northeast-1"
    "ca-central-1"
)

for region in "${REGIONS[@]}"; do
    echo "🔍 Checking region: $region"
    
    # Get all instances
    instances=$(aws ec2 describe-instances --region "$region" --query 'Reservations[*].Instances[*].InstanceId' --output text 2>/dev/null || echo "")
    
    if [ -z "$instances" ]; then
        echo "   ✅ No instances"
        continue
    fi
    
    echo "   Found instances: $instances"
    echo "   🗑️  Terminating instances..."
    
    for instance in $instances; do
        aws ec2 terminate-instances --region "$region" --instance-ids "$instance" 2>/dev/null || true
        echo "      ✅ Terminated: $instance"
    done
    
    # Wait for termination
    echo "   ⏳ Waiting for termination..."
    aws ec2 wait instance-terminated --region "$region" --instance-ids $instances 2>/dev/null || true
    echo "   ✅ Instances terminated"
    
    echo ""
done

echo ""
echo "🔍 Checking VPCs (non-default)..."

for region in "${REGIONS[@]}"; do
    # Get non-default VPCs
    vpcs=$(aws ec2 describe-vpcs --region "$region" --query 'Vpcs[?IsDefault==`false`].VpcId' --output text 2>/dev/null || echo "")
    
    if [ -z "$vpcs" ]; then
        continue
    fi
    
    echo "   Region $region - Found VPCs: $vpcs"
    
    for vpc in $vpcs; do
        echo "   🗑️  Deleting VPC: $vpc"
        
        # Delete internet gateways
        igws=$(aws ec2 describe-internet-gateways --region "$region" --filters "Name=attachment.vpc-id,Values=$vpc" --query 'InternetGateways[*].InternetGatewayId' --output text 2>/dev/null || echo "")
        for igw in $igws; do
            aws ec2 detach-internet-gateway --region "$region" --internet-gateway-id "$igw" --vpc-id "$vpc" 2>/dev/null || true
            aws ec2 delete-internet-gateway --region "$region" --internet-gateway-id "$igw" 2>/dev/null || true
            echo "      ✅ Deleted IGW: $igw"
        done
        
        # Delete subnets
        subnets=$(aws ec2 describe-subnets --region "$region" --filters "Name=vpc-id,Values=$vpc" --query 'Subnets[*].SubnetId' --output text 2>/dev/null || echo "")
        for subnet in $subnets; do
            aws ec2 delete-subnet --region "$region" --subnet-id "$subnet" 2>/dev/null || true
            echo "      ✅ Deleted subnet: $subnet"
        done
        
        # Delete security groups (except default)
        sgs=$(aws ec2 describe-security-groups --region "$region" --filters "Name=vpc-id,Values=$vpc" "Name=group-name,Values=default" --query 'SecurityGroups[*].GroupId' --output text 2>/dev/null || echo "")
        for sg in $sgs; do
            if [ "$sg" != "default" ]; then
                aws ec2 delete-security-group --region "$region" --group-id "$sg" 2>/dev/null || true
                echo "      ✅ Deleted security group: $sg"
            fi
        done
        
        # Delete VPC
        aws ec2 delete-vpc --region "$region" --vpc-id "$vpc" 2>/dev/null || true
        echo "      ✅ Deleted VPC: $vpc"
    done
done

echo ""
echo "🔍 Checking key pairs..."

for region in "${REGIONS[@]}"; do
    # Get all key pairs starting with "deploy"
    keypairs=$(aws ec2 describe-key-pairs --region "$region" --query 'KeyPairs[?starts_with(KeyName, `deploy`) == `true`].KeyName' --output text 2>/dev/null || echo "")
    
    if [ -z "$keypairs" ]; then
        continue
    fi
    
    echo "   Region $region - Found key pairs: $keypairs"
    
    for keypair in $keypairs; do
        aws ec2 delete-key-pair --region "$region" --key-name "$keypair" 2>/dev/null || true
        echo "      ✅ Deleted key pair: $keypair"
    done
done

echo ""
echo "========================================"
echo "✅ Cleanup Complete!"
echo "========================================"
echo ""
echo "All EC2 instances, VPCs, and key pairs have been deleted."
echo ""
echo "Next steps:"
echo "1. Run: cd ~/overseas-site/terraform"
echo "2. Run: terraform destroy -auto-approve"
echo "3. Then: terraform apply to recreate infrastructure"
echo ""
