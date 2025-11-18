# Nagios Monitoring - Troubleshooting Guide

## Quick Diagnostics

Run this from WSL Ubuntu to check Nagios status:

```bash
cd ~/overseas-site/ansible
bash nagios-diagnostic.sh
```

This will check:
- SSH connectivity
- Nagios service status
- Apache service status
- Nagios process running
- Configuration validity
- Port availability
- Permissions and logs

---

## Common Nagios Issues

### Issue 1: Nagios Service Not Running

**Symptoms:**
- Cannot access http://13.233.112.94
- Port 80 not responding
- Nagios service status: inactive

**Fix:**
```bash
ssh -i ~/.ssh/deploy-key ubuntu@13.233.112.94

# Check status
sudo systemctl status nagios
sudo systemctl status apache2

# Start services
sudo systemctl start nagios
sudo systemctl start apache2

# Enable on boot
sudo systemctl enable nagios
sudo systemctl enable apache2

# Verify
curl http://localhost
```

### Issue 2: Nagios Not Installed Properly

**Symptoms:**
- `/usr/local/nagios/bin/nagios` not found
- Compilation errors during Ansible

**Fix:**
```bash
ssh -i ~/.ssh/deploy-key ubuntu@13.233.112.94

# Check if installed
ls -la /usr/local/nagios/

# If missing, manually install
cd /tmp
wget https://github.com/NagiosEnterprises/nagioscore/releases/download/nagios-4.4.13/nagios-4.4.13.tar.gz
tar xzf nagios-4.4.13.tar.gz
cd nagios-4.4.13

./configure --with-command-group=nagcmd --prefix=/usr/local/nagios
make all
sudo make install
sudo make install-init
sudo make install-config
sudo make install-webconf

# Set permissions
sudo chown -R nagios:nagios /usr/local/nagios
sudo chmod -R 755 /usr/local/nagios
```

### Issue 3: Nagios Configuration Error

**Symptoms:**
```
Error in configuration file '/usr/local/nagios/etc/nagios.cfg'
```

**Fix:**
```bash
ssh -i ~/.ssh/deploy-key ubuntu@13.233.112.94

# Validate config
sudo /usr/local/nagios/bin/nagios -v /usr/local/nagios/etc/nagios.cfg

# Look for errors, then fix cfg files
sudo nano /usr/local/nagios/etc/nagios.cfg
sudo nano /usr/local/nagios/etc/servers/app.cfg

# Restart after fixing
sudo systemctl restart nagios
```

### Issue 4: Apache Not Serving Nagios

**Symptoms:**
- Port 80 not listening
- Cannot connect to web UI
- Apache error in logs

**Fix:**
```bash
ssh -i ~/.ssh/deploy-key ubuntu@13.233.112.94

# Check Apache status
sudo systemctl status apache2

# Enable required modules
sudo a2enmod rewrite
sudo a2enmod cgi
sudo a2enmod version
sudo a2enmod auth_basic
sudo a2enmod authn_file
sudo a2enmod authz_user

# Enable Nagios site
sudo a2ensite nagios.conf

# Test config
sudo apache2ctl configtest

# Restart
sudo systemctl restart apache2

# Check port 80
sudo netstat -tlnp | grep :80
```

### Issue 5: Cannot Access Web UI

**Symptoms:**
- http://13.233.112.94 times out or refuses connection
- Connection refused error

**Possible Causes:**
1. Security group doesn't allow port 80 from your IP
2. Apache not running
3. Nagios conf missing

**Fix:**
```bash
# 1. Check security group in AWS Console
# Inbound rule: HTTP (80) from your IP

# 2. Check if port is open
ssh -i ~/.ssh/deploy-key ubuntu@13.233.112.94 "sudo netstat -tlnp | grep :80"

# 3. Restart services
ssh -i ~/.ssh/deploy-key ubuntu@13.233.112.94 << 'EOF'
sudo systemctl restart apache2
sudo systemctl restart nagios
sleep 2
curl http://localhost
EOF

# 4. Test from local
curl http://13.233.112.94
```

### Issue 6: Authentication Failed

**Symptoms:**
- 401 Unauthorized error
- Cannot login with nagios/nagios123

**Fix:**
```bash
ssh -i ~/.ssh/deploy-key ubuntu@13.233.112.94

# Check htpasswd file
sudo ls -la /usr/local/nagios/etc/htpasswd.users

# Reset password
sudo htpasswd -cb /usr/local/nagios/etc/htpasswd.users nagios nagios123

# Fix permissions
sudo chown nagios:nagios /usr/local/nagios/etc/htpasswd.users
sudo chmod 640 /usr/local/nagios/etc/htpasswd.users

# Restart Apache
sudo systemctl restart apache2
```

### Issue 7: Nagios Not Monitoring App Server

**Symptoms:**
- Nagios UI shows but no hosts/services
- "No Objects To Display"

**Fix:**
```bash
ssh -i ~/.ssh/deploy-key ubuntu@13.233.112.94

# Check config files
ls -la /usr/local/nagios/etc/servers/

# Verify app.cfg
sudo cat /usr/local/nagios/etc/servers/app.cfg

# Should have correct IP: 10.0.1.14
# Update if needed:
sudo nano /usr/local/nagios/etc/servers/app.cfg

# Validate
sudo /usr/local/nagios/bin/nagios -v /usr/local/nagios/etc/nagios.cfg

# Restart
sudo systemctl restart nagios
```

### Issue 8: NRPE Agent Not Responding

**Symptoms:**
- Services show "UNKNOWN" status
- NRPE connection refused errors

**Fix on App Server:**
```bash
ssh -i ~/.ssh/deploy-key ubuntu@13.127.218.112

# Check NRPE status
sudo systemctl status nagios-nrpe-server

# Restart
sudo systemctl restart nagios-nrpe-server

# Verify port 5666
sudo netstat -tlnp | grep 5666

# Check config
sudo cat /etc/nagios/nrpe.cfg | grep allowed_hosts
```

**Fix on Nagios Server:**
```bash
ssh -i ~/.ssh/deploy-key ubuntu@13.233.112.94

# Test NRPE connection
/usr/local/nagios/libexec/check_nrpe -H 10.0.1.14 -c check_load

# Should return CPU load, not error
```

---

## Step-by-Step Nagios Verification

### 1. Check Nagios Service
```bash
ssh -i ~/.ssh/deploy-key ubuntu@13.233.112.94
sudo systemctl status nagios

# Should show: active (running)
```

### 2. Validate Configuration
```bash
sudo /usr/local/nagios/bin/nagios -v /usr/local/nagios/etc/nagios.cfg

# Should show: "Things look okay!"
```

### 3. Test Local Access
```bash
curl http://localhost/nagios
# Should show Nagios login page HTML
```

### 4. Check Apache
```bash
sudo systemctl status apache2
sudo netstat -tlnp | grep :80

# Should show apache2 listening on port 80
```

### 5. Access Web UI
```bash
# From your computer
curl http://13.233.112.94
# Should see Nagios HTML or 401 if auth required
```

### 6. Login
```
URL: http://13.233.112.94
Username: nagios
Password: nagios123
```

### 7. Verify Monitoring
- Should see "nextjs-app" host
- Should see services: HTTP, CPU Load, Disk, Memory

---

## Complete Nagios Reinstall (If Broken)

If Nagios is completely broken, SSH into Nagios server and:

```bash
# Stop services
sudo systemctl stop nagios
sudo systemctl stop apache2

# Remove old installation (CAREFUL!)
sudo rm -rf /usr/local/nagios

# Run Ansible again
# From your local machine:
cd ~/overseas-site/ansible
ansible-playbook -i inventory.ini nagios-playbook.yml
```

---

## Quick Command Reference

```bash
# SSH into Nagios server
ssh -i ~/.ssh/deploy-key ubuntu@13.233.112.94

# Service management
sudo systemctl status nagios
sudo systemctl restart nagios
sudo systemctl start nagios
sudo systemctl stop nagios

# Apache management
sudo systemctl status apache2
sudo systemctl restart apache2

# Configuration validation
sudo /usr/local/nagios/bin/nagios -v /usr/local/nagios/etc/nagios.cfg

# Check services
sudo systemctl is-active nagios
sudo systemctl is-enabled nagios

# View logs
sudo tail -20 /var/log/nagios/nagios.log
sudo tail -20 /var/log/apache2/error.log

# Test NRPE
/usr/local/nagios/libexec/check_nrpe -H 10.0.1.14 -c check_load

# Port checks
sudo netstat -tlnp | grep :80
sudo netstat -tlnp | grep :5666
```

---

## Nagios Web UI Default Credentials

| Setting | Value |
|---------|-------|
| URL | http://13.233.112.94 |
| Username | nagios |
| Password | nagios123 |

**⚠️ Change password in production!**

```bash
ssh -i ~/.ssh/deploy-key ubuntu@13.233.112.94
sudo htpasswd /usr/local/nagios/etc/htpasswd.users nagios
```

---

## Useful Resources

- **Nagios Home:** `/usr/local/nagios/`
- **Config:** `/usr/local/nagios/etc/nagios.cfg`
- **Logs:** `/var/log/nagios/nagios.log`
- **Plugins:** `/usr/local/nagios/libexec/`
- **Web Dir:** `/usr/local/nagios/share/`

---

## Still Not Working?

Run the diagnostic script:
```bash
cd ~/overseas-site/ansible
bash nagios-diagnostic.sh
```

This will show you exactly what's wrong. Share the output for specific help!
