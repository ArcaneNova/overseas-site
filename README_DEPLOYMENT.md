# BN Overseas - Deployment Summary

## Current State

✅ **Infrastructure**: AWS (eu-north-1) with Terraform
✅ **Application**: Next.js 14 with TypeScript
✅ **Process Manager**: PM2
✅ **Web Server**: Nginx (reverse proxy)
✅ **Monitoring**: Nagios
✅ **Monitoring Agent**: NRPE
✅ **Configuration Management**: Ansible
✅ **App Server IP**: 13.61.181.123 (10.0.1.167)
✅ **Nagios Server IP**: 16.16.215.8 (10.0.1.225)

## Quick Start

See `QUICK_START.md` for complete deployment instructions.

### One Command to Deploy Everything

```bash
cd ~/overseas-site/ansible

# First time only - fix SSH keys and recreate infrastructure
bash fix-key-complete.sh

# Then deploy everything
bash deploy-all.sh
```

## Project Structure

```
bnoverseas-app/
├── terraform/              # AWS infrastructure (Terraform IaC)
│   ├── main.tf            # VPC, EC2, security groups
│   └── variables.tf       # AWS region, instance types
├── ansible/               # Deployment automation
│   ├── inventory.ini      # Server inventory
│   ├── playbook.yml       # App server deployment
│   ├── nagios-playbook.yml    # Nagios deployment
│   ├── vars.yml           # Environment variables
│   ├── fix-key-complete.sh    # SSH key fix (RUN FIRST)
│   ├── deploy-app.sh      # Deploy app only
│   ├── deploy-nagios.sh   # Deploy Nagios only
│   └── deploy-all.sh      # Deploy both
├── QUICK_START.md         # Deployment guide & troubleshooting
├── app/                   # Next.js application
├── components/            # React components
├── lib/                   # Utilities & API clients
├── prisma/               # Database schema
└── public/               # Static assets
```

## Key Files (Cleaned Up)

✅ Removed unnecessary debugging scripts
✅ Removed old documentation files
✅ Removed backup files
✅ Kept only essential deployment automation

## Current Infrastructure
- **App Server**: EC2 t3.medium (Ubuntu 22.04)
  - Public IP: 13.235.135.216
  - Private IP: 10.0.1.245
  - URL: http://13.235.135.216
  
- **Nagios Server**: EC2 t3.small (Ubuntu 22.04)
  - Public IP: 13.234.114.114
  - Private IP: 10.0.1.107
  - URL: http://13.234.114.114 (nagios/nagios123)

### Networking
- **VPC**: 10.0.0.0/16
- **Public Subnet**: 10.0.1.0/24
- **Security Groups**: 
  - App: SSH (22), HTTP (80)
  - Nagios: SSH (22), HTTP (80), NRPE (5666)

## Deployment Checklist

- [ ] Run `bash fix-key-complete.sh` (handles SSH keys + infrastructure)
- [ ] Run `bash deploy-all.sh` (deploys app + Nagios)
- [ ] Verify app at `http://IP`
- [ ] Access Nagios at `http://NAGIOS_IP` (nagios/nagios123)

## Common Commands

```bash
# SSH into app server
ssh -i ~/.ssh/deploy-key ubuntu@13.235.135.216

# SSH into Nagios
ssh -i ~/.ssh/deploy-key ubuntu@13.234.114.114

# Check app status
ssh -i ~/.ssh/deploy-key ubuntu@13.235.135.216 pm2 status

# View app logs
ssh -i ~/.ssh/deploy-key ubuntu@13.235.135.216 pm2 logs nextjs-app

# Check Nagios status
ssh -i ~/.ssh/deploy-key ubuntu@13.234.114.114 sudo systemctl status nagios

# Destroy all AWS resources
cd terraform && terraform destroy -auto-approve
```

## Documentation

- **QUICK_START.md** - Deployment guide, IPs, access info, troubleshooting
- **terraform/** - AWS infrastructure as code
- **ansible/** - Configuration management & deployment scripts

## Support

For detailed troubleshooting, see the **Troubleshooting** section in `QUICK_START.md`.

## Environment Variables

All environment variables are stored in `ansible/vars.yml` and loaded during Ansible deployment to `.env.local` on the app server.

**Key variables:**
- `DATABASE_URL` - PostgreSQL connection
- `NEXTAUTH_SECRET` - Authentication secret
- `NEXTAUTH_URL` - OAuth callback URL
- AWS credentials and API keys
- SMTP configuration

## Security Notes

⚠️ **Production Security:**
1. Change Nagios default password
2. Update SSH key permissions (done automatically)
3. Restrict security groups to your IP
4. Enable HTTPS on Nginx
5. Rotate secrets and API keys regularly
6. Enable AWS CloudWatch monitoring

## Maintenance

**Logs to monitor:**
- `/var/log/nginx/` - Web server
- `/var/log/pm2/` - Application
- `/var/log/nagios/` - Monitoring

**Update checks:**
```bash
# On app server
pm2 logs nextjs-app

# On Nagios server
sudo tail -f /var/log/nagios/nagios.log
```

---

**Last Updated**: November 18, 2025
**Infrastructure**: AWS ap-south-1
**Status**: Ready for deployment
