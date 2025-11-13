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

**After terraform apply succeeds, note the outputs:**
- `app_public_ip` → Use this in Ansible inventory 13.127.218.112
- `app_private_ip` → Use this for NEXTAUTH_URL and Nagios 13.127.218.112
- `nagios_public_ip` → Use this for Nagios access 13.127.218.112
- `nagios_private_ip` → Use this in app's NRPE config 13.127.218.112

### 1.4 Example output:
```
Outputs:

app_private_ip = "10.0.1.XX"
app_public_ip = "54.X.X.X"
nagios_private_ip = "10.0.1.YY"
nagios_public_ip = "54.X.X.Y"
```

---

## Step 2: Configure Ansible Inventory & Variables

### 2.1 Update ansible/inventory.ini
```bash
cd ../ansible
```

Edit `inventory.ini` and replace:
- `APP_PUBLIC_IP` with actual app public IP from Terraform
- `APP_PRIVATE_IP` with actual app private IP from Terraform
- `NAGIOS_PUBLIC_IP` with actual Nagios public IP from Terraform

Example:
```ini
[app]
54.1.2.3 ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/deploy-key ansible_host=54.1.2.3 private_ip=10.0.1.10

[nagios]
54.4.5.6 ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/deploy-key ansible_host=54.4.5.6

[all:vars]
ansible_python_interpreter=/usr/bin/python3
```

### 2.2 Create ansible/vars.yml for environment variables
```bash
cat > vars.yml << 'EOF'
# Copy all values from your local .env file
database_url: "your_database_url_here"
jwt_secret: "your_jwt_secret_here"
jwt_refresh_secret: "your_jwt_refresh_secret_here"
nextauth_secret: "your_nextauth_secret_here"

smtp_host: "smtp.gmail.com"
smtp_port: "587"
smtp_user: "your_email@gmail.com"
smtp_pass: "your_app_password"
from_email: "noreply@bnoverseas.com"

aws_access_key_id: "your_aws_key"
aws_secret_access_key: "your_aws_secret"
aws_region: "ap-south-1"
aws_s3_bucket: "bnoverseas-uploads"

stripe_secret_key: "your_stripe_secret"
stripe_publishable_key: "your_stripe_public"
razorpay_key_id: "your_razorpay_key"
razorpay_key_secret: "your_razorpay_secret"

zoom_api_key: "your_zoom_key"
zoom_api_secret: "your_zoom_secret"
twilio_account_sid: "your_twilio_sid"
twilio_auth_token: "your_twilio_token"
EOF
```

### 2.3 Update playbook.yml
Replace `YOUR_USERNAME` in the github_repo with your actual GitHub username:
```yaml
github_repo: "https://github.com/YOUR_USERNAME/bnoverseas.git"
```

---

## Step 3: Deploy Application with Ansible

### 3.1 Test connectivity
```bash
ansible all -i inventory.ini -m ping
```

### 3.2 Run playbook with environment variables
```bash
ansible-playbook -i inventory.ini playbook.yml \
  -e @vars.yml \
  -e "ansible_host=$(terraform output -raw app_public_ip)"
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
curl http://APP_PUBLIC_IP
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

### 4.2 Access Nagios Web UI
```
URL: http://NAGIOS_PUBLIC_IP
Username: nagios
Password: nagios123
```

---

## Step 5: Connect App to Nagios

### 5.1 Update Nagios app config with correct IPs
SSH into Nagios server:
```bash
ssh -i ~/.ssh/deploy-key ubuntu@NAGIOS_PUBLIC_IP
```

Edit the app config:
```bash
sudo nano /usr/local/nagios/etc/servers/app.cfg
```

Replace `APP_PRIVATE_IP` with the actual private IP from Terraform.

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
ssh -i ~/.ssh/deploy-key ubuntu@APP_PUBLIC_IP
```

### Check PM2 Status
```bash
ssh -i ~/.ssh/deploy-key ubuntu@APP_PUBLIC_IP
pm2 status
```

### View PM2 Logs
```bash
ssh -i ~/.ssh/deploy-key ubuntu@APP_PUBLIC_IP
pm2 logs nextjs-app
```

### SSH into Nagios Server
```bash
ssh -i ~/.ssh/deploy-key ubuntu@NAGIOS_PUBLIC_IP
```

### Check Nagios Service
```bash
ssh -i ~/.ssh/deploy-key ubuntu@NAGIOS_PUBLIC_IP
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
