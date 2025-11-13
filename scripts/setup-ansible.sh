#!/usr/bin/env bash

# Quick setup script for Ansible and dependencies

set -e

echo "=========================================="
echo "Setting up Ansible Environment"
echo "=========================================="

# Check Python
if ! command -v python3 &> /dev/null; then
    echo "Python 3 is required. Installing..."
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        sudo apt-get update
        sudo apt-get install -y python3 python3-pip
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        brew install python3
    fi
fi

# Install Ansible
echo "Installing Ansible..."
pip3 install --user ansible

# Install boto3 for AWS modules
echo "Installing boto3..."
pip3 install --user boto3 botocore

echo "=========================================="
echo "Ansible environment ready!"
echo "=========================================="

# Show versions
echo ""
python3 --version
ansible --version
