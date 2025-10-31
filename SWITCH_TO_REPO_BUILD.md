# Switch from Docker Image to Repository Build

## Current Setup (Docker Image)
- ❌ Source: Docker Registry
- ❌ Image: `twentycrm/twenty:latest`
- ❌ Pre-built image (can't get latest code changes)

## Target Setup (Repository Build)
- ✅ Source: GitHub Repository
- ✅ Build: From Dockerfile in repo
- ✅ Gets latest code changes

---

## Changes Needed in Railway Dashboard

### For MAIN Twenty Service (Server)

1. **Go to Railway Dashboard:**
   - Open: https://railway.com/project/cda9fd62-f906-45fd-9c42-73561a5f319c
   - Find and click on **"Twenty"** or **"Server"** service (NOT the worker)

2. **Change Source (Settings → Source):**
   - Current: `Docker Image` with `twentycrm/twenty:latest`
   - **Change to:** `GitHub Repository`
   - Select your repository
   - Branch: `main` (or your default branch)
   - Root Directory: Leave empty (uses repository root)

3. **Configure Build (Settings → Build):**
   ```
   Builder: DOCKERFILE
   Dockerfile Path: packages/twenty-docker/twenty/Dockerfile
   ```

4. **Configure Deploy (Settings → Deploy):**
   ```
   Start Command: (LEAVE EMPTY - DO NOT SET ANYTHING)

   Health Check Path: /healthz
   Health Check Timeout: 100

   Restart Policy: On Failure
   Restart Policy Max Retries: 10
   ```

5. **Save and Deploy:**
   - Click **"Save"** if there's a save button
   - Go to **Deployments** tab
   - Click **"New Deployment"** or **"Deploy"**

---

### For Twenty Worker Service (Already Configured)

Worker is already using the repository and has correct settings:
- ✅ Start Command: `yarn worker:prod`
- ✅ Dockerfile Path: `packages/twenty-docker/twenty/Dockerfile`

**No changes needed for worker!**

---

## Why These Settings?

### Server Start Command: EMPTY (Critical!)

**❌ WRONG:**
```bash
Start Command: node dist/src/main
Start Command: yarn start:prod
Start Command: (anything)
```

**✅ CORRECT:**
```bash
Start Command: (empty/blank)
```

**Why?**
- The Dockerfile has an ENTRYPOINT script (`entrypoint.sh`)
- This script MUST run first to:
  - Check database schema
  - Run migrations if needed
  - Register cron jobs
- Then it automatically starts: `node dist/src/main`
- Setting a custom start command **bypasses the entrypoint** and breaks migrations

### Dockerfile Path

```
packages/twenty-docker/twenty/Dockerfile
```

This is the path **relative to repository root** where the Dockerfile exists.

---

## Step-by-Step Visual Guide

### Step 1: Navigate to Service Settings

```
Railway Dashboard
  └─ Projects
      └─ twenty-crm
          └─ [Click on] Twenty/Server service (NOT worker)
              └─ Click "Settings" tab
```

### Step 2: Change Source

```
Settings → Source Section

Current:
  ┌─────────────────────────────┐
  │ Source: Docker Image        │
  │ Image: twentycrm/twenty:... │
  └─────────────────────────────┘

Change to:
  ┌─────────────────────────────┐
  │ Source: GitHub Repository   │
  │ Repo: your-twenty-crm-repo  │
  │ Branch: main                │
  │ Root: (empty)               │
  └─────────────────────────────┘
```

### Step 3: Configure Build

```
Settings → Build Section

  ┌─────────────────────────────────────────────┐
  │ Builder: DOCKERFILE                         │
  │                                             │
  │ Dockerfile Path:                            │
  │ packages/twenty-docker/twenty/Dockerfile    │
  │                                             │
  │ [ ] Watch Paths (leave default)             │
  └─────────────────────────────────────────────┘
```

### Step 4: Configure Deploy

```
Settings → Deploy Section

  ┌─────────────────────────────────────────────┐
  │ Start Command:                              │
  │ [                              ] ← EMPTY    │
  │                                             │
  │ Health Check Path: /healthz                 │
  │ Health Check Timeout: 100                   │
  │                                             │
  │ Restart Policy: On Failure                  │
  │ Max Retries: 10                             │
  └─────────────────────────────────────────────┘
```

### Step 5: Deploy

```
Click "Deployments" tab
  └─ Click "New Deployment" button
      └─ Monitor build progress (5-10 minutes)
          └─ Check logs for successful deployment
```

---

## What to Expect During Deployment

### Build Phase (5-10 minutes)

```
Building...
├─ Cloning repository
├─ Installing dependencies (yarn install)
├─ Building backend (nx run twenty-server:build)
├─ Building frontend (nx build twenty-front)
├─ Creating Docker image
└─ Build complete ✓
```

### Deploy Phase (2-5 minutes)

```
Deploying...
├─ Starting container
├─ Running entrypoint.sh
│   ├─ Checking database schema
│   ├─ Running migrations (if needed)
│   └─ Registering cron jobs
├─ Starting server (node dist/src/main)
├─ Server listening on port 3000
├─ Health check: /healthz → 200 OK
└─ Deployment successful ✓
```

### Success Indicators

✅ Build completed successfully
✅ "Successfully migrated DB!" in logs
✅ "Application is running on: http://[::]:3000" in logs
✅ Health check passing (green indicator)
✅ Service shows as "Active"

---

## Verification Checklist

After deployment, verify:

### Server Service
- [ ] Source is "GitHub Repository" (not Docker Image)
- [ ] Dockerfile path is `packages/twenty-docker/twenty/Dockerfile`
- [ ] Start command is **EMPTY**
- [ ] Health check path is `/healthz`
- [ ] Service is Active/Healthy
- [ ] Can access app at Railway domain

### Logs Show Success
- [ ] "Successfully migrated DB!"
- [ ] "Successfully registered all background sync jobs!"
- [ ] "Application is running on: http://[::]:3000"
- [ ] No errors in recent logs

### App Works
- [ ] Can load Railway domain URL
- [ ] Login/signup page appears
- [ ] Can create account or login
- [ ] Dashboard loads correctly

---

## Troubleshooting

### Build Fails

**Error: "Dockerfile not found"**
- Check path: `packages/twenty-docker/twenty/Dockerfile`
- Ensure root directory is empty (uses repo root)

**Error: "Dependencies failed to install"**
- Check package.json is valid
- Ensure yarn.lock is committed
- Try redeploying

### Deploy Fails

**Error: "Health check timeout"**
- Increase timeout to 100+ seconds
- Check server is actually starting (view logs)

**Error: "Migration failed"**
- Check DATABASE_URL is correct
- Ensure PostgreSQL service is running
- Check worker has `DISABLE_DB_MIGRATIONS=true`

**Error: "Port binding failed"**
- Ensure PORT=3000 is set
- Check no other service is using port 3000

---

## Rollback Plan

If something goes wrong:

1. **Revert to Docker Image:**
   - Settings → Source
   - Change to: Docker Image
   - Image: `twentycrm/twenty:latest`
   - Deploy

2. **Or Redeploy Previous Version:**
   - Deployments → Find last working deployment
   - Click "Redeploy"

---

## Quick Reference

### Server Configuration Summary

```yaml
Source: GitHub Repository
Branch: main
Root: (empty)

Build:
  Builder: DOCKERFILE
  Path: packages/twenty-docker/twenty/Dockerfile

Deploy:
  Start Command: (EMPTY)
  Health Check: /healthz (100s timeout)
  Restart: On Failure (10 retries)
```

### Commands to Test Locally

```bash
# Test Dockerfile builds:
docker build -f packages/twenty-docker/twenty/Dockerfile -t twenty-test .

# Test container runs:
docker run -p 3000:3000 \
  -e PORT=3000 \
  -e PG_DATABASE_URL=your-db-url \
  -e REDIS_URL=your-redis-url \
  -e APP_SECRET=your-secret \
  twenty-test
```

---

## Timeline Expectations

- **Configuration changes**: 5 minutes
- **First build from repo**: 8-12 minutes
- **Deploy + health check**: 3-5 minutes
- **Total**: ~15-20 minutes for first deployment

**Subsequent deployments**: ~10 minutes (Railway caches layers)

---

## Need Help?

If you encounter issues:

1. Check logs in Railway dashboard
2. Review `RAILWAY_CONFIGURATION_ANALYSIS.md`
3. Compare your settings with this guide
4. Ensure all environment variables are still set

---

**Ready to switch?** Follow the steps above in your Railway dashboard!
