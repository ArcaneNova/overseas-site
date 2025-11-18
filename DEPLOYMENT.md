# Complete AWS Deployment Guide - Next.js with Terraform, Ansible & Nagios

## Overview

This guide covers complete infrastructure deployment using:
- **Terraform** - Infrastructure as Code (IaC) for AWS
- **Ansible** - Configuration management and application deployment
- **Nagios** - System monitoring and alerting

## Prerequisites

### On Windows with WSL2 Ubuntu

1. **AWS Account** with credentials configured
2. **WSL2 Ubuntu** installed and running
3. **Required tools in WSL:**
   - Terraform
   - Ansible
   - AWS CLI
   - SSH keys

### Quick Setup (if not done)

```bash
# 1. In WSL Ubuntu, configure AWS credentials
aws configure
# Enter: Access Key ID, Secret Access Key, Region (eu-north-1), Format (json)

# 2. Create SSH keypair
mkdir -p ~/.ssh
ssh-keygen -t rsa -b 4096 -f ~/.ssh/deploy-key -N ""

# 3. Verify setup
aws sts get-caller-identity
ssh-keygen -lf ~/.ssh/deploy-key
```

---

## Step 1: Terraform - Infrastructure Provisioning

### 1.1 What Terraform Does

Creates the following AWS infrastructure:
- **VPC**: 10.0.0.0/16 with public subnet 10.0.1.0/24
- **Internet Gateway**: For public internet access
- **2 EC2 Instances**:
  - App Server: t3.medium (Ubuntu 22.04) - Runs Next.js app
  - Nagios Server: t3.small (Ubuntu 22.04) - Runs monitoring
- **Security Groups**: Allow SSH (22), HTTP (80), NRPE (5666)
- **SSH Key Pair**: References your local deploy-key

### 1.2 Configuration Files

**terraform/variables.tf:**
```hcl
variable "aws_region" {
  default = "eu-north-1"  # Your region
}

variable "ssh_public_key_path" {
  default = "~/.ssh/deploy-key.pub"
}

variable "app_instance_type" {
  default = "t3.medium"
}

variable "nagios_instance_type" {
  default = "t3.small"
}
```

**terraform/main.tf:**
- VPC with public subnet
- Internet Gateway
- Route tables and associations
- Two security groups (app and nagios)
- Two EC2 instances

### 1.3 Deploy Infrastructure

```bash
# In WSL Ubuntu
cd ~/overseas-site/terraform

# Initialize Terraform
terraform init

# Review what will be created
terraform plan

# Create infrastructure on AWS
terraform apply

# View outputs (your instance IPs)
terraform output
```

**Expected Output:**
```
app_public_ip = "13.62.222.157"
app_private_ip = "10.0.1.117"
nagios_public_ip = "13.48.24.241"
nagios_private_ip = "10.0.1.212"
```

### 1.4 Troubleshooting Terraform

**Error: "The keypair already exists"**
- Solution: Run `terraform destroy` first, then `terraform apply`

**Error: "SSH key not found"**
- Check: `ls -la ~/.ssh/deploy-key*`
- Fix: Regenerate keys: `ssh-keygen -t rsa -b 4096 -f ~/.ssh/deploy-key -N ""`

**Instances created but can't SSH**
- Wait 30 seconds for instances to fully boot
- Check security group allows your IP on port 22
- Verify key permissions: `chmod 600 ~/.ssh/deploy-key`

---

## Step 2: Ansible - Configuration & Deployment

### 2.1 What Ansible Does

**On App Server:**
- Installs Node.js 18 and npm
- Installs Nginx (reverse proxy)
- Installs PM2 (process manager)
- Clones your GitHub repository
- Installs dependencies
- Builds Next.js application
- Starts application with PM2
- Configures Nginx to proxy requests to app
- Installs NRPE monitoring agent

**On Nagios Server:**
- Installs Nagios Core
- Installs Nagios Plugins
- Installs Apache web server
- Configures Nagios UI
- Sets up host and service monitoring
- Configures NRPE check commands

### 2.2 Ansible Configuration

**ansible/inventory.ini:**
```ini
[app]
13.62.222.157 ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/deploy-key ansible_host=13.62.222.157 private_ip=10.0.1.117

[nagios]
13.48.24.241 ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/deploy-key ansible_host=13.48.24.241 private_ip=10.0.1.212

[all:vars]
ansible_python_interpreter=/usr/bin/python3
```

**ansible/vars.yml:**
Contains all environment variables from your `.env` file:
- Database connection string
- Authentication secrets
- API keys
- SMTP configuration
- etc.

**ansible/playbook.yml:**
Main deployment playbook for app server

**ansible/nagios-playbook.yml:**
Deployment playbook for Nagios server

### 2.3 Fix SSH Keys First

If you have SSH key authentication errors:

```bash
cd ~/overseas-site/ansible

# This script handles everything:
# - Creates new SSH key pair
# - Registers with AWS
# - Terminates old instances
# - Recreates infrastructure
# - Updates inventory
# - Tests connectivity
bash fix-key-complete.sh
```

### 2.4 Deploy Application Server

```bash
cd ~/overseas-site/ansible

# Option 1: Deploy app only
ansible-playbook -i inventory.ini playbook.yml -e @vars.yml

# Option 2: Use helper script
bash deploy-app.sh
```

**What happens:**
1. Node.js installed
2. Repository cloned from GitHub
3. Dependencies installed (with --legacy-peer-deps for compatibility)
4. Next.js app built
5. PM2 started with app process
6. Nginx configured to proxy port 80 → port 3000
7. NRPE installed for monitoring

**Expected time:** 5-10 minutes

**Verify success:**
```bash
curl http://13.62.222.157  # Should show your Next.js app
```

### 2.5 Deploy Nagios Server

```bash
cd ~/overseas-site/ansible

# Option 1: Deploy Nagios only
ansible-playbook -i inventory.ini nagios-playbook.yml

# Option 2: Use helper script
bash deploy-nagios.sh
```

**What happens:**
1. Nagios Core compiled from source
2. Nagios plugins installed
3. Apache configured with Nagios site
4. Nagios users and permissions set
5. Host and service definitions configured
6. NRPE configured for remote checks

**Expected time:** 3-5 minutes

**Verify success:**
```bash
# Access Nagios UI
http://13.48.24.241
# Username: nagios
# Password: nagios123
```

### 2.6 Deploy Everything at Once

```bash
cd ~/overseas-site/ansible
bash deploy-all.sh
```

This runs:
1. SSH host key acceptance
2. Ansible ping test
3. App server deployment
4. Nagios server deployment
5. Status verification

**Total time:** ~20 minutes

### 2.7 Troubleshooting Ansible

**Error: "Unable to parse inventory"**
- Check: Are you in `~/overseas-site/ansible` directory?
- Fix: `cd ~/overseas-site/ansible && pwd`

**Error: "Permission denied (publickey)"**
- Fix: Run the SSH key fix script:
  ```bash
  bash fix-key-complete.sh
  ```

**Error: "npm ERESOLVE unable to resolve dependency tree"**
- This is normal - the playbook includes `--legacy-peer-deps` flag
- Just re-run the playbook

**Ansible hangs or times out**
- Wait a bit more (instances might still be booting)
- Or manually test: `ansible all -i inventory.ini -m ping`

**Application not running after deployment**
```bash
ssh -i ~/.ssh/deploy-key ubuntu@X.X.X.X

# Check PM2 status
pm2 status

# View logs
pm2 logs nextjs-app

# Restart if needed
pm2 restart nextjs-app
```

---

## Step 3: Verification & Testing

### 3.1 Test Application Access

```bash
# From your local machine
curl http://13.62.222.157

# Or open in browser
http://13.62.222.157
```

Should show your Next.js application HTML.

### 3.2 Test Nagios Access

```bash
# From your local machine
http://13.48.24.241

# Login with:
# Username: nagios
# Password: nagios123
```

Should show Nagios dashboard with your app server listed.

### 3.3 Check Services

**On App Server:**
```bash
ssh -i ~/.ssh/deploy-key ubuntu@13.62.222.157

# Check PM2
pm2 status
pm2 logs nextjs-app

# Check Nginx
sudo systemctl status nginx
sudo tail -20 /var/log/nginx/error.log

# Check NRPE
sudo systemctl status nagios-nrpe-server
```

**On Nagios Server:**
```bash
ssh -i ~/.ssh/deploy-key ubuntu@13.48.24.241

# Check Nagios
sudo systemctl status nagios
sudo tail -20 /var/log/nagios/nagios.log

# Check Apache
sudo systemctl status apache2

# Check connectivity to app server
/usr/local/nagios/libexec/check_nrpe -H 10.0.1.117 -c check_load
```

---

## Complete Deployment Workflow

### Quick Start (if everything is ready)

```bash
cd ~/overseas-site

# 1. Create infrastructure (~5 min)
cd terraform
terraform apply -auto-approve
cd ..

# 2. Get new IPs
cd terraform
terraform output
cd ../ansible

# 3. Update inventory with new IPs
# Edit ansible/inventory.ini with the new IPs

# 4. Fix SSH keys if needed
bash fix-key-complete.sh

# 5. Deploy everything (~20 min)
bash deploy-all.sh

# 6. Access
# App: http://13.62.222.157
# Nagios: http://13.48.24.241 (nagios/nagios123)
```

### Step-by-Step Manual Process

```bash
# Step 1: Terraform
cd terraform
terraform init
terraform plan
terraform apply
APP_IP=$(terraform output -raw app_public_ip)
NAGIOS_IP=$(terraform output -raw nagios_public_ip)
cd ..

# Step 2: Update Ansible inventory with new IPs
# Edit ansible/inventory.ini

# Step 3: Ansible - App Server
cd ansible
ansible-playbook -i inventory.ini playbook.yml -e @vars.yml

# Step 4: Ansible - Nagios
ansible-playbook -i inventory.ini nagios-playbook.yml

# Step 5: Test
curl http://13.62.222.157
curl http://13.48.24.241/nagios
```

---

## Environment Variables

All variables from your `.env` file are configured in `ansible/vars.yml`:

```yaml
# Database
database_url: "postgresql://..."

# Authentication
nextauth_secret: "your-secret"
nextauth_url: "http://X.X.X.X"

# Mail
smtp_host: "..."
smtp_user: "..."
smtp_pass: "..."

# API Keys
razorpay_key: "..."
aws_access_key: "..."
# ... etc
```

These are automatically loaded during Ansible deployment to `~/.nextjs-app/.env.local` on the app server.

---

## Maintenance & Monitoring

### Daily Operations

```bash
# Monitor app
ssh -i ~/.ssh/deploy-key ubuntu@13.62.222.157 pm2 logs

# Monitor Nagios
ssh -i ~/.ssh/deploy-key ubuntu@13.48.24.241 sudo tail -f /var/log/nagios/nagios.log

# Check Nagios dashboard
http://13.48.24.241
```

### Common Tasks

**Restart application:**
```bash
ssh -i ~/.ssh/deploy-key ubuntu@13.62.222.157 pm2 restart nextjs-app
```

**Restart monitoring:**
```bash
ssh -i ~/.ssh/deploy-key ubuntu@13.48.24.241 sudo systemctl restart nagios
```

**View Nginx error log:**
```bash
ssh -i ~/.ssh/deploy-key ubuntu@13.62.222.157 sudo tail -50 /var/log/nginx/error.log
```

**Update configuration:**
```bash
cd ~/overseas-site/ansible

# Update vars.yml with new environment variables
# Re-run playbook
ansible-playbook -i inventory.ini playbook.yml -e @vars.yml
```

---

## Cleanup & Destruction

### Destroy All AWS Resources

```bash
cd ~/overseas-site/terraform
terraform destroy -auto-approve
```

⚠️ **Warning:** This deletes:
- EC2 instances
- VPC and subnets
- Security groups
- Internet gateway
- Key pairs

---

## Security Recommendations

### For Production

1. **Change Nagios Password:**
   ```bash
   ssh -i ~/.ssh/deploy-key ubuntu@Y.Y.Y.Y
   sudo htpasswd /usr/local/nagios/etc/htpasswd.users nagios
   ```

2. **Restrict SSH Access:**
   Update `terraform/variables.tf`:
   ```hcl
   variable "my_ip_cidr" {
     default = "YOUR_IP/32"  # Replace with your actual IP
   }
   ```

3. **Enable HTTPS:**
   Configure SSL certificates on Nginx

4. **Enable Backups:**
   Set up AWS backup policies for databases

5. **Rotate Secrets:**
   Regularly update API keys and secrets in `ansible/vars.yml`

---

## Troubleshooting Summary

| Issue | Solution |
|-------|----------|
| SSH key mismatch | Run `bash fix-key-complete.sh` |
| Terraform errors | Check AWS credentials: `aws sts get-caller-identity` |
| Ansible inventory not found | Ensure you're in `~/overseas-site/ansible` |
| App not accessible | SSH in and check `pm2 status` and Nginx logs |
| Nagios not accessible | SSH in and check Apache: `sudo systemctl status apache2` |
| Monitoring not working | Verify NRPE on app server: `/usr/local/nagios/libexec/check_nrpe -H 10.0.1.X -c check_load` |

---

## Support Files

- **QUICK_START.md** - Quick reference and additional troubleshooting
- **README_DEPLOYMENT.md** - Project overview and structure
- **terraform/** - Infrastructure code
- **ansible/** - Deployment automation scripts

---

**Last Updated:** November 18, 2025  
**Region:** eu-north-1  
**Status:** Ready for deployment
