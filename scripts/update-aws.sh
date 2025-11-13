#!/usr/bin/env bash

# Script to update Docker image and push to AWS automatically
# Run this after making code changes

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

echo "=========================================="
echo "Building and Pushing Docker Image"
echo "=========================================="

# Build image
echo "Building Docker image..."
docker build -t bnoverseas-app:latest .

if [ $? -ne 0 ]; then
    echo "Docker build failed!"
    exit 1
fi

# Trigger update on AWS via git
echo ""
echo "Pushing code to repository..."
git add -A
git commit -m "Automated deployment: $(date '+%Y-%m-%d %H:%M:%S')" || true
git push origin main

if [ $? -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "✓ Code pushed successfully!"
    echo "Application will auto-update on AWS within 5 minutes"
    echo "=========================================="
else
    echo "Git push failed!"
    exit 1
fi
