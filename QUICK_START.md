# Quick Deployment Guide

## Current Infrastructure
- **App Server**: 13.235.135.216 (private: 10.0.1.245)
- **Nagios Server**: 13.234.114.114 (private: 10.0.1.107)

## To Deploy Everything

Run these commands in WSL Ubuntu:

```bash
cd ~/overseas-site/ansible

# FIX SSH KEY MISMATCH FIRST (run this once, takes ~3 minutes)
bash fix-key-complete.sh

# Then deploy app server (takes 5-10 minutes)
bash deploy-app.sh

# Then deploy Nagios server (takes 3-5 minutes)
bash deploy-nagios.sh
```

Or do everything at once after the fix:
```bash
bash deploy-all.sh
```

**What `fix-key-complete.sh` does:**
- ✅ Creates brand new SSH key pair in AWS
- ✅ Terminates all old instances  
- ✅ Cleans Terraform state
- ✅ Recreates infrastructure with correct keys
- ✅ Updates inventory with new IPs
- ✅ Tests connectivity automatically

## Access Your Services

### Next.js App
- **URL**: http://13.235.135.216
- **Repository**: https://github.com/ArcaneNova/overseas-site

### Nagios Monitoring
- **URL**: http://13.234.114.114
- **Username**: nagios
- **Password**: nagios123

## Manual Commands (if needed)

### Test connectivity only
```bash
cd ~/overseas-site/ansible
ansible all -i inventory.ini -m ping
```

### Deploy app only
```bash
cd ~/overseas-site/ansible
ansible-playbook -i inventory.ini playbook.yml -e @vars.yml
```

### Deploy Nagios only
```bash
cd ~/overseas-site/ansible
ansible-playbook -i inventory.ini nagios-playbook.yml
```

### SSH into servers
```bash
# App server
ssh -i ~/.ssh/deploy-key ubuntu@13.235.135.216

# Nagios server
ssh -i ~/.ssh/deploy-key ubuntu@13.234.114.114
```

### Check service status
```bash
# Check PM2 app status
ssh -i ~/.ssh/deploy-key ubuntu@13.235.135.216 pm2 status

# Check Nagios status
ssh -i ~/.ssh/deploy-key ubuntu@13.234.114.114 sudo systemctl status nagios

# Check Nginx status
ssh -i ~/.ssh/deploy-key ubuntu@13.235.135.216 sudo systemctl status nginx
```

## Troubleshooting

### SSH Permission Denied (publickey)
If you see "Permission denied (publickey)" error, run this comprehensive fix:

```bash
cd ~/overseas-site/ansible
bash fix-key-complete.sh
```

This script will:
1. Create a completely new SSH key pair
2. Register it with AWS
3. Terminate all old instances
4. Recreate infrastructure with the correct key
5. Update your inventory with new IPs
6. Test connectivity to verify everything works

**The script handles everything automatically** - just run it and wait for "✅ SSH Key Fix Complete!"

### If Ansible says "inventory not found"
Make sure you're in the ansible directory:
```bash
cd ~/overseas-site/ansible
pwd  # Should show: /root/overseas-site/ansible
```

### If SSH key permission denied
```bash
chmod 600 ~/.ssh/deploy-key
```

### Check deployment logs
```bash
# App server Nginx
ssh -i ~/.ssh/deploy-key ubuntu@13.235.135.216 sudo tail -50 /var/log/nginx/error.log

# App server PM2
ssh -i ~/.ssh/deploy-key ubuntu@13.235.135.216 pm2 logs

# Nagios
ssh -i ~/.ssh/deploy-key ubuntu@13.234.114.114 sudo tail -50 /var/log/nagios/nagios.log
```

## Files Changed

- ✅ `ansible/inventory.ini` - Updated with new IPs
- ✅ `DEPLOYMENT.md` - Updated with new IPs
- ✅ `ansible/deploy-app.sh` - New script for app deployment
- ✅ `ansible/deploy-nagios.sh` - New script for Nagios deployment
- ✅ `ansible/deploy-all.sh` - New script to deploy everything
