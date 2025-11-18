# Nginx Reverse Proxy Issue - Debug & Fix

## Problem
After Ansible deployment, visiting `http://13.127.218.112` shows default Nginx page instead of Next.js app.

## Root Cause
Nginx may not have properly linked the `nextjs` site configuration, or handlers weren't triggered.

## Solution

### From WSL Ubuntu terminal:

**Option 1: Quick Fix (Recommended)**
```bash
cd ~/overseas-site/ansible
bash fix-nginx.sh
```

This script will:
1. ✅ Check PM2 status
2. ✅ Test localhost:3000 connectivity
3. ✅ Remove default Nginx site link
4. ✅ Create nextjs site link if missing
5. ✅ Test Nginx config
6. ✅ Restart Nginx
7. ✅ Test public IP access

**Option 2: Manual Steps**
```bash
# SSH into app server
ssh -i ~/.ssh/deploy-key ubuntu@13.127.218.112

# Check PM2
pm2 status

# Test app locally
curl http://localhost:3000

# Fix Nginx
sudo rm -f /etc/nginx/sites-enabled/default
sudo ln -sf /etc/nginx/sites-available/nextjs /etc/nginx/sites-enabled/nextjs
sudo nginx -t
sudo systemctl restart nginx

# Test from outside
exit
curl http://13.127.218.112
```

## Verification Checklist

After running fix:

- [ ] PM2 shows `nextjs-app` as `online`
- [ ] `curl http://localhost:3000` shows HTML output
- [ ] `/etc/nginx/sites-enabled/default` doesn't exist
- [ ] `/etc/nginx/sites-enabled/nextjs` is a symlink
- [ ] `nginx -t` shows "successful"
- [ ] `curl http://13.127.218.112` shows Next.js page

## Expected Result

You should see your Next.js app HTML instead of:
```
Welcome to nginx!
If you see this page, the nginx web server is successfully installed and working.
```

## Troubleshooting

### App still showing Nginx default page
```bash
# Check if nextjs site is enabled
ssh -i ~/.ssh/deploy-key ubuntu@13.127.218.112 "ls -la /etc/nginx/sites-enabled/"

# Should show:
# nextjs -> /etc/nginx/sites-available/nextjs

# Check Nginx error log
sudo tail -20 /var/log/nginx/error.log
```

### Port 3000 connection refused
```bash
# Check if PM2 app is running
pm2 status

# Restart app
pm2 restart nextjs-app

# Check logs
pm2 logs nextjs-app
```

### Still seeing default nginx page
```bash
# Force reload Nginx
sudo systemctl stop nginx
sudo systemctl start nginx

# Or check if service is listening
sudo netstat -tlnp | grep -E ':(80|3000)'
```

## Quick Commands

```bash
# SSH in
ssh -i ~/.ssh/deploy-key ubuntu@13.127.218.112

# Check everything
pm2 status
curl http://localhost:3000
ls -la /etc/nginx/sites-enabled/
sudo nginx -t

# Restart services
pm2 restart nextjs-app
sudo systemctl restart nginx

# View logs
pm2 logs nextjs-app
sudo tail -20 /var/log/nginx/error.log
```

---

Once fixed, you should see your Next.js app at: **http://13.127.218.112** ✅
