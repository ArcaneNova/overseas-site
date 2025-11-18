# SSH Host Key Verification Issue - Solution

## Problem
```
[ERROR]: Task failed: Failed to connect to the host via ssh: Host key verification failed.
```

## Root Cause
SSH requires verifying host keys on first connection. The EC2 instances haven't been added to `~/.ssh/known_hosts` yet.

## Solution

### Option 1: Disable Host Key Checking (Quick - for testing)
```bash
export ANSIBLE_HOST_KEY_CHECKING=False
ansible all -i inventory.ini -m ping
```

### Option 2: Accept Host Keys (Recommended - for production)

**From WSL Ubuntu terminal:**

```bash
cd ~/overseas-site/ansible
bash setup-ssh.sh
```

Or manually:
```bash
ssh-keyscan -H 13.127.218.112 >> ~/.ssh/known_hosts
ssh-keyscan -H 13.233.112.94 >> ~/.ssh/known_hosts
```

### Option 3: Configure Ansible
Edit `ansible.cfg`:
```bash
cat > ~/overseas-site/ansible/ansible.cfg << 'EOF'
[defaults]
host_key_checking = False
inventory = inventory.ini
EOF
```

Then run:
```bash
ansible all -i inventory.ini -m ping
```

## Recommended Flow

1. **Accept host keys:**
   ```bash
   bash setup-ssh.sh
   ```

2. **Test connectivity:**
   ```bash
   ansible all -i inventory.ini -m ping
   ```

3. **If servers are not ready yet:**
   - Wait 30-60 seconds for EC2 instances to fully boot
   - Run the ping command again

4. **Once ping succeeds:**
   ```bash
   ansible-playbook -i inventory.ini playbook.yml -e @vars.yml
   ```

## Expected Success Output
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

## Troubleshooting

### Servers still not responding
- **Issue:** EC2 instances need time to boot
- **Solution:** Wait 60 seconds and try again

### Connection refused
- **Issue:** SSH port 22 not open in security group
- **Solution:** Check AWS console → Security Groups → Inbound Rules

### Permission denied (publickey)
- **Issue:** Wrong SSH key or key permissions
- **Solution:** 
  ```bash
  chmod 600 ~/.ssh/deploy-key
  ls -la ~/.ssh/deploy-key
  ```

### Host key not found
- **Issue:** Unable to reach the instance
- **Solution:** Verify IPs are correct from Terraform output
  ```bash
  cd ../terraform
  terraform output
  ```
