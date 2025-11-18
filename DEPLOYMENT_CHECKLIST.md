# 🚀 BN Overseas - Deployment Checklist

## ✅ Infrastructure Status

### Terraform Deployment - COMPLETE
- [x] VPC created (10.0.0.0/16)
- [x] Public subnet created (10.0.1.0/24)
- [x] Internet Gateway configured
- [x] Route tables configured
- [x] SSH Key pair created
- [x] Security groups created
- [x] 2 EC2 instances launched

### Your Infrastructure Details

| Component | Public IP | Private IP | Type |
|-----------|-----------|-----------|------|
| **App Server** | 13.127.218.112 | 10.0.1.14 | t3.medium |
| **Nagios Server** | 13.233.112.94 | 10.0.1.37 | t3.small |

---

## 📋 Next Steps (Ansible Deployment)

### Step 1: Verify Connectivity
```bash
cd ~/overseas-site/ansible
ansible all -i inventory.ini -m ping
```

**Expected Output:**
```
app_server | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
nagios_server | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

---

### Step 2: Deploy Next.js Application
```bash
ansible-playbook -i inventory.ini playbook.yml -e @vars.yml
```

**What it installs:**
- ✅ Node.js 18.x
- ✅ npm dependencies
- ✅ Nginx reverse proxy
- ✅ PM2 process manager
- ✅ NRPE monitoring agent
- ✅ .env.local with all variables

**Estimated time:** 10-15 minutes

---

### Step 3: Deploy Nagios Monitoring
```bash
ansible-playbook -i inventory.ini nagios-playbook.yml
```

**What it installs:**
- ✅ Nagios Core 4.4.13
- ✅ Nagios Plugins
- ✅ Apache2 web server
- ✅ NRPE agent
- ✅ Web UI with authentication

**Estimated time:** 8-10 minutes

---

### Step 4: Configure Nagios
```bash
ssh -i ~/.ssh/deploy-key ubuntu@13.233.112.94
sudo nano /usr/local/nagios/etc/servers/app.cfg
```

Change line with `address` to:
```
address                 10.0.1.14
```

Restart Nagios:
```bash
sudo /usr/local/nagios/bin/nagios -v /usr/local/nagios/etc/nagios.cfg
sudo systemctl restart nagios
```

---

## 📊 Access Points

| Service | URL | Credentials |
|---------|-----|-------------|
| **App** | http://13.127.218.112 | None (public) |
| **Nagios** | http://13.233.112.94 | nagios / nagios123 |

---

## 🔧 Quick Commands

### Check App Status
```bash
ssh -i ~/.ssh/deploy-key ubuntu@13.127.218.112
pm2 status
pm2 logs nextjs-app
```

### Check Nagios Status
```bash
ssh -i ~/.ssh/deploy-key ubuntu@13.233.112.94
sudo systemctl status nagios
```

### View Logs
```bash
# App logs
tail -50 /var/log/nginx/error.log
pm2 logs nextjs-app

# Nagios logs
sudo tail -50 /var/log/nagios/nagios.log
```

---

## 🔒 Security Notes

1. **SSH Security**: Restrict `my_ip_cidr` in `terraform/variables.tf` to your IP
2. **Change Nagios Password**: Update `nagios123` after first login
3. **HTTPS Setup**: Add Let's Encrypt SSL certificate to Nginx
4. **Database Access**: Ensure DB is only accessible from app server

---

## ⚠️ Troubleshooting

### Ansible can't connect
```bash
chmod 600 ~/.ssh/deploy-key
ansible all -i inventory.ini -m ping
```

### App not starting
```bash
ssh -i ~/.ssh/deploy-key ubuntu@13.127.218.112
pm2 logs nextjs-app
# Check for build errors or missing environment variables
```

### Database connection error
```bash
# Verify DATABASE_URL in vars.yml is correct
# Check if PostgreSQL is accessible from app server
```

---

## 📈 Monitoring Dashboard

Once Nagios is running, access:
```
http://13.233.112.94
```

You can monitor:
- ✅ HTTP service availability
- ✅ CPU load
- ✅ Disk usage
- ✅ Memory consumption

---

## 🎉 Deployment Complete!

After all steps are done:
1. Visit http://13.127.218.112 → See your app running
2. Visit http://13.233.112.94 → See Nagios monitoring
3. Setup is complete! Your Next.js app is live on AWS

---

**Infrastructure Created:** Nov 13, 2025  
**Status:** Ready for Ansible Deployment  
**Next Action:** Run Ansible playbooks
