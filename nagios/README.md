# Nagios Monitoring Configuration

This directory contains reference files for Nagios monitoring setup.

## How it works:

1. **Installation & Setup**: Done by `ansible/nagios-playbook.yml`
   - Installs Nagios Core, Plugins, and Apache
   - Configures web UI with authentication
   - Sets up initial host/service definitions

2. **Host Monitoring**:
   - The app EC2 instance is monitored via NRPE (Nagios Remote Plugin Executor)
   - Nagios server queries the app instance on port 5666

3. **Monitored Services**:
   - HTTP (port 80)
   - CPU Load
   - Disk Usage
   - Memory Usage

## Access Nagios Web UI:

```
URL: http://NAGIOS_PUBLIC_IP
Username: nagios
Password: nagios123
```

## Manual Configuration (if needed):

Host definitions are in: `/usr/local/nagios/etc/servers/app.cfg`

To modify:
```bash
ssh -i ~/.ssh/deploy-key ubuntu@NAGIOS_PUBLIC_IP
sudo nano /usr/local/nagios/etc/servers/app.cfg
sudo /usr/local/nagios/bin/nagios -v /usr/local/nagios/etc/nagios.cfg
sudo systemctl restart nagios
```

## Troubleshooting:

```bash
# Check if Nagios is running
sudo systemctl status nagios

# Check if NRPE is responding on app server
ssh -i ~/.ssh/deploy-key ubuntu@APP_PUBLIC_IP
sudo systemctl status nagios-nrpe-server
```
