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
ssh -i ~/.ssh/deploy-key ubuntu@13.62.222.157

# Nagios server
ssh -i ~/.ssh/deploy-key ubuntu@13.48.24.241
```

### Check service status
```bash
# Check PM2 app status
ssh -i ~/.ssh/deploy-key ubuntu@13.62.222.157 pm2 status

# Check Nagios status
ssh -i ~/.ssh/deploy-key ubuntu@13.48.24.241 sudo systemctl status nagios

# Check Nginx status
ssh -i ~/.ssh/deploy-key ubuntu@13.62.222.157 sudo systemctl status nginx
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

### Ansible says "inventory not found"
Make sure you're in the correct directory:
```bash
cd ~/overseas-site/ansible
pwd  # Should show: /root/overseas-site/ansible
```

The `inventory.ini` file must be in the ansible directory.

### SSH Key permission denied (after fix)
```bash
chmod 600 ~/.ssh/deploy-key
chmod 644 ~/.ssh/deploy-key.pub
```

### Check deployment logs

**App server logs:**
```bash
# SSH into app server
ssh -i ~/.ssh/deploy-key ubuntu@13.62.222.157

# View PM2 application logs
pm2 logs nextjs-app

# View Nginx error logs
sudo tail -100 /var/log/nginx/error.log

# View Nginx access logs
sudo tail -50 /var/log/nginx/access.log

# Check PM2 status
pm2 status

# Check Nginx status
sudo systemctl status nginx
```

**Nagios server logs:**
```bash
# SSH into Nagios server
ssh -i ~/.ssh/deploy-key ubuntu@13.48.24.241

# View Nagios logs
sudo tail -100 /var/log/nagios/nagios.log

# Check Nagios status
sudo systemctl status nagios

# Check Apache status
sudo systemctl status apache2

# Validate Nagios config
sudo /usr/local/nagios/bin/nagios -v /usr/local/nagios/etc/nagios.cfg
```

### App not accessible at http://IP
```bash
# SSH into app server
ssh -i ~/.ssh/deploy-key ubuntu@13.62.222.157

# Check if PM2 is running
pm2 status

# Start/restart the app if needed
pm2 restart nextjs-app

# Check if Nginx is running
sudo systemctl status nginx

# Check Nginx config for errors
sudo nginx -t

# Test local connection
curl http://localhost:3000
curl http://localhost

# View Nginx error log
sudo tail -50 /var/log/nginx/error.log
```

### Nagios not accessible at http://IP
```bash
# SSH into Nagios server
ssh -i ~/.ssh/deploy-key ubuntu@13.48.24.241

# Check Apache status
sudo systemctl status apache2

# Check if Nagios is running
sudo systemctl status nagios

# Restart both if needed
sudo systemctl restart apache2
sudo systemctl restart nagios

# Test local access
curl http://localhost/nagios

# Check if port 80 is listening
sudo netstat -tlnp | grep :80

# Check Apache error log
sudo tail -50 /var/log/apache2/error.log
```

### Database connection errors
If the app shows database errors:
```bash
# SSH into app server
ssh -i ~/.ssh/deploy-key ubuntu@13.62.222.157

# Check .env file was created
cat ~/.nextjs-app/.env.local | head -20

# View PM2 logs for database errors
pm2 logs nextjs-app | grep -i database

# Verify DATABASE_URL is set
echo $DATABASE_URL
```

### Nagios not monitoring app server
```bash
# SSH into Nagios server
ssh -i ~/.ssh/deploy-key ubuntu@13.48.24.241

# Check NRPE status on app server via Nagios
/usr/local/nagios/libexec/check_nrpe -H 10.0.1.117 -c check_load

# Check Nagios config for app
sudo cat /usr/local/nagios/etc/servers/app.cfg

# The address should be the private IP: 10.0.1.117
# Restart if config changed
sudo systemctl restart nagios
```

### Re-run Ansible playbooks
If something fails during deployment, you can re-run:

```bash
cd ~/overseas-site/ansible

# Deploy app only
ansible-playbook -i inventory.ini playbook.yml -e @vars.yml

# Deploy Nagios only
ansible-playbook -i inventory.ini nagios-playbook.yml

# Both
bash deploy-all.sh
```

Ansible is idempotent - re-running won't cause problems, it will fix any missing configuration.

### Completely restart infrastructure
If everything is broken:

```bash
cd ~/overseas-site/ansible

# 1. Fix the SSH key and recreate infrastructure
bash fix-key-complete.sh

# 2. Deploy everything fresh
bash deploy-all.sh
```

### Get help
Check these sources:
- **Next.js logs**: `pm2 logs nextjs-app`
- **Nginx errors**: `/var/log/nginx/error.log`
- **Nagios config**: `/usr/local/nagios/etc/nagios.cfg`
- **Ansible inventory**: `ansible-inventory -i inventory.ini --list`

## Files Changed

- ✅ `ansible/inventory.ini` - Updated with new IPs
- ✅ `DEPLOYMENT.md` - Updated with new IPs
- ✅ `ansible/deploy-app.sh` - New script for app deployment
- ✅ `ansible/deploy-nagios.sh` - New script for Nagios deployment
- ✅ `ansible/deploy-all.sh` - New script to deploy everything
