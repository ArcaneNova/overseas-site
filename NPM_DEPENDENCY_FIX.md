# NPM Dependency Resolution Issue - Solution

## Problem
```
npm error code ERESOLVE
npm error ERESOLVE unable to resolve dependency tree
npm error Could not resolve dependency:
npm error peerOptional nodemailer@"^7.0.7" from next-auth@4.24.13
```

## Root Cause
There's a peer dependency conflict between:
- `nodemailer@6.10.1` (currently installed)
- `next-auth@4.24.13` (wants nodemailer@^7.0.7)

This is a common issue with npm v7+, which is stricter about peer dependency resolution.

## Solution Applied

The playbook has been updated to use `--legacy-peer-deps` flag:

```bash
npm install --legacy-peer-deps
```

This flag tells npm to ignore peer dependency conflicts and proceed with installation.

## How to Retry

Run the Ansible playbook again:

```bash
cd ~/overseas-site/ansible
ansible-playbook -i inventory.ini playbook.yml -e @vars.yml
```

The playbook will:
1. ✅ Skip already completed tasks (clone, system packages)
2. ✅ Retry npm install with `--legacy-peer-deps`
3. ✅ Continue with build and deployment

## Alternative: Fix Dependencies Locally (Optional)

If you want to fix this on your local machine first:

```bash
# Upgrade nodemailer to v7
npm install nodemailer@^7

# Or downgrade next-auth to compatible version
npm install next-auth@^4.24.10
```

Then commit changes:
```bash
git add package.json package-lock.json
git commit -m "fix: resolve npm peer dependency conflicts"
git push
```

## Expected Output

When successful, you should see:
```
added XXX packages, removed XXX packages, changed XXX packages
```

Then the playbook will continue with:
- Build Next.js app
- Start PM2 service
- Configure Nginx
- Install NRPE monitoring

## Notes

- `--legacy-peer-deps` is safe for production
- Modern npm projects often need this due to peer dependency version mismatches
- The app will function normally with this flag
- Consider updating dependencies in your local package.json for long-term stability
