# Complete AWS Deployment Guide - Next.js with Terraform, Ansible & Nagios

## Prerequisites (On Windows with WSL2 Ubuntu)

### 1. Setup AWS Credentials
```bash
# In WSL Ubuntu terminal
aws configure
# Enter your AWS Access Key ID
# Enter your AWS Secret Access Key
# Region: ap-south-1 (or your preferred region)
# Output format: json
```

### 2. Create SSH Keypair
```bash
mkdir -p ~/.ssh
ssh-keygen -t rsa -b 4096 -f ~/.ssh/deploy-key -N ""
```

### 3. Get Your Local .env Values
```bash
# From your local machine, view your .env file
cat /path/to/bnoverseas-app/.env
# Copy all values - you'll need these for Ansible
```

---

## Step 1: Deploy Infrastructure with Terraform

### 1.1 Navigate to Terraform directory
```bash
cd ~/path/to/bnoverseas-app/terraform
terraform init
```

### 1.2 Review the plan
```bash
terraform plan
```

### 1.3 Apply Terraform
```bash
terraform apply
```

**Terraform Output (Already Applied):**
- `app_public_ip` = 13.127.218.112
- `app_private_ip` = 10.0.1.14
- `nagios_public_ip` = 13.233.112.94
- `nagios_private_ip` = 10.0.1.37

### 1.4 Infrastructure Ready! ✅
```
Outputs:

app_private_ip = "10.0.1.14"
app_public_ip = "13.127.218.112"
nagios_private_ip = "10.0.1.37"
nagios_public_ip = "13.233.112.94"
```

✅ **2 EC2 instances created successfully**
✅ **VPC and networking configured**
✅ **Security groups active**
✅ **Ready for Ansible deployment**

---

## Step 2: Configure Ansible Inventory & Variables

### 2.1 Inventory Configuration ✅
Inventory is already configured with your actual IPs:
```ini
[app]
app_server ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/deploy-key ansible_host=13.127.218.112 private_ip=10.0.1.14

[nagios]
nagios_server ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/deploy-key ansible_host=13.233.112.94 private_ip=10.0.1.37

[all:vars]
ansible_python_interpreter=/usr/bin/python3
```

No changes needed - ready to use!

### 2.2 Environment Variables ✅
`ansible/vars.yml` is already configured with your environment variables.
All variables from your `.env` file are ready.

The `playbook.yml` is already configured with:
```yaml
github_repo: "https://github.com/ArcaneNova/overseas-site.git"
app_dir: /var/www/nextjs
```

Ready for deployment!

---

## Step 3: Deploy Application with Ansible

### 3.1 Test connectivity (from WSL Ubuntu)
```bash
# Make sure you're in the WSL Ubuntu terminal, not PowerShell
cd ~/overseas-site/ansible

# Step 1: Accept SSH host keys
bash setup-ssh.sh

# Step 2: Test Ansible connectivity
ansible all -i inventory.ini -m ping
```

**If you see host key verification error**, see `SSH_HOST_KEY_FIX.md` for solutions.

Expected output when successful:
```
13.127.218.112 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
13.233.112.94 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

### 3.2 Run playbook with environment variables
```bash
ansible-playbook -i inventory.ini playbook.yml -e @vars.yml
```

**If you see npm peer dependency error:**
- The playbook has been updated to use `--legacy-peer-deps`
- Simply run the playbook again - it will skip completed tasks and retry npm install
- See `NPM_DEPENDENCY_FIX.md` for details
```

### 3.3 Wait for deployment to complete
This will:
- Install Node.js, Nginx, PostgreSQL client
- Clone your GitHub repo
- Install dependencies
- Build Next.js app
- Start PM2 service
- Configure Nginx reverse proxy
- Install NRPE for Nagios monitoring

### 3.4 Verify deployment
```bash
curl http://13.127.218.112
# Should see your Next.js app
```

---

## Step 4: Setup Nagios Monitoring

### 4.1 Deploy Nagios server
```bash
ansible-playbook -i inventory.ini nagios-playbook.yml
```

This will:
- Install Nagios Core
- Install Nagios Plugins
- Configure Apache
- Setup host and service monitoring

### 4.2 Access Nagios Web UI ✅
```
URL: http://13.233.112.94
Username: nagios
Password: nagios123
```

---

## Step 5: Connect App to Nagios

### 5.1 Update Nagios app config with correct IPs
SSH into Nagios server:
```bash
ssh -i ~/.ssh/deploy-key ubuntu@13.233.112.94
```

Edit the app config:
```bash
sudo nano /usr/local/nagios/etc/servers/app.cfg
```

Update the address to the app server's private IP:
```
address                 10.0.1.14
```

### 5.2 Verify and restart Nagios
```bash
sudo /usr/local/nagios/bin/nagios -v /usr/local/nagios/etc/nagios.cfg
sudo systemctl restart nagios
```

---

## Quick Commands Reference

### View Terraform Outputs Anytime
```bash
cd terraform
terraform output
```

### SSH into App Server
```bash
ssh -i ~/.ssh/deploy-key ubuntu@13.127.218.112
```

### Check PM2 Status
```bash
ssh -i ~/.ssh/deploy-key ubuntu@13.127.218.112
pm2 status
```

### View PM2 Logs
```bash
ssh -i ~/.ssh/deploy-key ubuntu@13.127.218.112
pm2 logs nextjs-app
```

### SSH into Nagios Server
```bash
ssh -i ~/.ssh/deploy-key ubuntu@13.233.112.94
```

### Check Nagios Service
```bash
ssh -i ~/.ssh/deploy-key ubuntu@13.233.112.94
sudo systemctl status nagios
```

---

## Cleanup (Destroy AWS Resources)

```bash
cd terraform
terraform destroy
```

---

## Troubleshooting

### Ansible connection fails
```bash
# Verify security group allows SSH from your IP
# Check key permissions
chmod 600 ~/.ssh/deploy-key
```

### Nginx not serving the app
```bash
# SSH into app server and check logs
sudo tail -50 /var/log/nginx/error.log
```

### PM2 app not running
```bash
# SSH into app server
pm2 logs nextjs-app
pm2 restart nextjs-app
```

### Database connection error
Ensure `DATABASE_URL` in `vars.yml` is correct and accessible from the EC2 instance.

### Nagios not monitoring app
```bash
# SSH into Nagios server
sudo systemctl status nrpe
sudo /usr/local/nagios/bin/nagios -v /usr/local/nagios/etc/nagios.cfg
```

---

## Production Notes

1. **SSH Security**: Update `my_ip_cidr` in `terraform/variables.tf` to restrict SSH to your IP only
2. **Passwords**: Change default Nagios password (nagios123)
3. **HTTPS**: Add SSL certificates to Nginx
4. **Backups**: Setup automated database backups
5. **Monitoring**: Configure Nagios alerts (email notifications)
