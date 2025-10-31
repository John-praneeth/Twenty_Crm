# Railway Configuration Analysis - Twenty CRM
## Comprehensive Investigation Report

**Date**: October 31, 2025
**Project**: twenty-crm
**Environment**: production
**Worker Service ID**: 1b704fbb-440a-4aaa-b81a-3c871db81617

---

## Executive Summary

After thorough investigation of:
- ✅ Official Railway Twenty CRM template
- ✅ Twenty CRM source code and scripts
- ✅ Dockerfile configuration
- ✅ Render deployment configuration
- ✅ Railway deployment best practices

**Key Finding**: Your project should be configured to **build from the repository** using the Dockerfile, NOT use the pre-built Docker image.

---

## 1. Official Railway Template Analysis

### Template URL
https://railway.com/template/nAL3hA

### Template Configuration

#### Main Twenty Service (from template)
```yaml
Image: twentycrm/twenty:latest
Pre-Deploy Command: yarn database:init:prod
Start Command: (default from Dockerfile)
Health Check: /healthz
Port: 3000
```

#### Twenty Worker Service (from template)
```yaml
Image: twentycrm/twenty:latest
Start Command: yarn worker:prod
Environment:
  DISABLE_DB_MIGRATIONS: true
  DISABLE_CRON_JOBS_REGISTRATION: true
```

**⚠️ IMPORTANT**: The template uses the **pre-built Docker image** (`twentycrm/twenty:latest`), but since you're working from the repository, you should build from source.

---

## 2. Dockerfile Analysis

### File Location
`packages/twenty-docker/twenty/Dockerfile`

### Build Process (Multi-Stage)

**Stage 1: common-deps**
- Base: `node:24-alpine`
- Installs dependencies with yarn
- Sets up Nx workspace

**Stage 2: twenty-server-build**
- Builds backend with `npx nx run twenty-server:build`
- Outputs to: `dist/` directory

**Stage 3: twenty-front-build**
- Builds frontend with `npx nx build twenty-front`
- Outputs to: `packages/twenty-front/build`

**Stage 4: twenty (Final)**
- Combines server + frontend
- Installs: curl, jq, tsx, postgresql-client
- **Working Directory**: `/app/packages/twenty-server`
- **ENTRYPOINT**: `/app/entrypoint.sh`
- **CMD**: `["node", "dist/src/main"]`

### Key Understanding

```dockerfile
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["node", "dist/src/main"]
```

This means:
1. **entrypoint.sh runs first** (handles migrations, cron jobs)
2. **Then executes CMD** (starts the application)
3. **For worker**: Override CMD to `yarn worker:prod`

---

## 3. Entrypoint Script Analysis

### File: `packages/twenty-docker/twenty/entrypoint.sh`

```bash
#!/bin/sh
set -e

setup_and_migrate_db() {
    if [ "${DISABLE_DB_MIGRATIONS}" = "true" ]; then
        echo "Database setup and migrations are disabled, skipping..."
        return
    fi

    echo "Running database setup and migrations..."
    has_schema=$(psql -tAc "SELECT EXISTS (SELECT 1...)" ${PG_DATABASE_URL})
    if [ "$has_schema" = "f" ]; then
        echo "Database appears to be empty, running migrations."
        NODE_OPTIONS="--max-old-space-size=1500" tsx ./scripts/setup-db.ts
        yarn database:migrate:prod
    fi

    yarn command:prod upgrade
    echo "Successfully migrated DB!"
}

register_background_jobs() {
    if [ "${DISABLE_CRON_JOBS_REGISTRATION}" = "true" ]; then
        echo "Cron job registration is disabled, skipping..."
        return
    fi

    echo "Registering background sync jobs..."
    yarn command:prod cron:register:all
    echo "Successfully registered all background sync jobs!"
}

setup_and_migrate_db
register_background_jobs

# Continue with the original Docker command
exec "$@"
```

**What it does:**
1. Checks if DB migrations should run (based on `DISABLE_DB_MIGRATIONS`)
2. If DB is empty, runs setup and migrations
3. Runs upgrade command
4. Registers cron jobs (if not disabled)
5. Executes the CMD (the `"$@"` part)

---

## 4. Render Configuration Analysis

### File: `render.yaml`

**Server Configuration:**
```yaml
dockerCommand: "sh -c ./scripts/render-run.sh"
```

**render-run.sh:**
```bash
#!/bin/sh
export PG_DATABASE_URL=postgres://postgres:postgres@$PG_DATABASE_HOST:$PG_DATABASE_PORT/default
yarn database:init:prod
node dist/src/main
```

**Worker Configuration:**
```yaml
dockerCommand: "sh -c ./scripts/render-worker.sh"
```

**render-worker.sh:**
```bash
#!/bin/sh
export PG_DATABASE_URL=postgres://postgres:postgres@$PG_DATABASE_HOST:$PG_DATABASE_PORT/default
node dist/src/queue-worker/queue-worker
```

**Key Insight**: Render uses custom scripts that:
1. Construct the DATABASE_URL
2. Run database initialization
3. Start the appropriate service

---

## 5. Package.json Scripts Analysis

### File: `packages/twenty-server/package.json`

```json
{
  "scripts": {
    "start:prod": "node dist/src/main",
    "command:prod": "node dist/src/command/command",
    "worker:prod": "node dist/src/queue-worker/queue-worker",
    "database:init:prod": "npx ts-node ./scripts/setup-db.ts && yarn database:migrate:prod",
    "database:migrate:prod": "npx -y typeorm migration:run -d dist/src/database/typeorm/core/core.datasource"
  }
}
```

**Key Commands:**
- `yarn database:init:prod` → Sets up DB + runs migrations
- `yarn start:prod` → `node dist/src/main` (web server)
- `yarn worker:prod` → `node dist/src/queue-worker/queue-worker` (worker)

---

## 6. Correct Railway Configuration

### For Main Twenty Service (Server)

**Build Settings:**
```yaml
Builder: DOCKERFILE
Dockerfile Path: packages/twenty-docker/twenty/Dockerfile
Root Directory: / (repository root)
```

**Deploy Settings:**
```yaml
Start Command: (empty - use Dockerfile default)
Health Check Path: /healthz
Health Check Timeout: 100 seconds
Restart Policy: On Failure
```

**Why no custom start command?**
- The Dockerfile already defines: `CMD ["node", "dist/src/main"]`
- The entrypoint.sh handles database migrations automatically
- Railway will use the Dockerfile's CMD by default

**Environment Variables:**
```bash
# Core
PORT=3000
SERVER_URL=${{RAILWAY_PUBLIC_DOMAIN}}
APP_SECRET=<secure-random-32-chars>

# Database
PG_DATABASE_URL=${{Postgres.DATABASE_URL}}

# Cache
REDIS_URL=${{Redis.REDIS_URL}}

# Server Behavior
DISABLE_DB_MIGRATIONS=false
DISABLE_CRON_JOBS_REGISTRATION=false

# Storage
STORAGE_TYPE=local
STORAGE_LOCAL_PATH=.local-storage
```

### For Twenty Worker Service

**Build Settings:**
```yaml
Builder: DOCKERFILE
Dockerfile Path: packages/twenty-docker/twenty/Dockerfile
Root Directory: / (repository root)
```

**Deploy Settings:**
```yaml
Start Command: yarn worker:prod  ⚠️ CRITICAL - Must override!
Restart Policy: On Failure
```

**Why custom start command?**
- Same Dockerfile, but different entry point
- Must override the CMD to start worker instead of server
- `yarn worker:prod` → runs `node dist/src/queue-worker/queue-worker`

**Environment Variables:**
```bash
# Core
SERVER_URL=${{twenty-server.RAILWAY_PUBLIC_DOMAIN}}
APP_SECRET=<same-as-server>

# Database
PG_DATABASE_URL=${{Postgres.DATABASE_URL}}

# Cache
REDIS_URL=${{Redis.REDIS_URL}}

# Worker Behavior (CRITICAL!)
DISABLE_DB_MIGRATIONS=true
DISABLE_CRON_JOBS_REGISTRATION=true

# Storage (must match server)
STORAGE_TYPE=local
STORAGE_LOCAL_PATH=.local-storage
```

---

## 7. Build vs Pre-built Image Comparison

### Option A: Pre-built Image (Railway Template Default)
```yaml
Source: Docker Image
Image: twentycrm/twenty:latest
```

**Pros:**
- ✅ Faster deployment (no build time)
- ✅ Consistent image across deployments
- ✅ Uses official Twenty builds

**Cons:**
- ❌ Can't customize code
- ❌ Must wait for official releases
- ❌ Can't test local changes

### Option B: Build from Repository (Recommended for You)
```yaml
Source: GitHub Repository
Builder: DOCKERFILE
Dockerfile Path: packages/twenty-docker/twenty/Dockerfile
```

**Pros:**
- ✅ Can modify and customize code
- ✅ Test changes before deploying
- ✅ Control over versions and updates
- ✅ Can hotfix issues immediately

**Cons:**
- ❌ Longer build time (~5-10 minutes)
- ❌ Uses Railway build minutes
- ❌ Need to maintain build configuration

**Your Situation**: Since you have the repository locally and are asking about configuration, you should use **Option B**.

---

## 8. Configuration Verification Checklist

### Server Service ✅

**Build Configuration:**
- [ ] Source: GitHub Repository
- [ ] Dockerfile Path: `packages/twenty-docker/twenty/Dockerfile`
- [ ] Root Directory: `/` (empty/default)
- [ ] Builder: DOCKERFILE

**Deploy Configuration:**
- [ ] Start Command: **(EMPTY - use Dockerfile default)**
- [ ] Health Check Path: `/healthz`
- [ ] Health Check Timeout: `100` seconds
- [ ] Restart Policy: `On Failure`

**Networking:**
- [ ] Public Domain: Generated
- [ ] Port: Auto-detected (3000)

**Environment Variables:**
- [ ] `PORT=3000`
- [ ] `SERVER_URL=${{RAILWAY_PUBLIC_DOMAIN}}`
- [ ] `APP_SECRET=<random-32-chars>`
- [ ] `PG_DATABASE_URL=${{Postgres.DATABASE_URL}}`
- [ ] `REDIS_URL=${{Redis.REDIS_URL}}`
- [ ] `DISABLE_DB_MIGRATIONS=false`
- [ ] `DISABLE_CRON_JOBS_REGISTRATION=false`
- [ ] `STORAGE_TYPE=local`

### Worker Service ✅

**Build Configuration:**
- [ ] Source: GitHub Repository (same as server)
- [ ] Dockerfile Path: `packages/twenty-docker/twenty/Dockerfile`
- [ ] Root Directory: `/` (empty/default)
- [ ] Builder: DOCKERFILE

**Deploy Configuration:**
- [ ] Start Command: **`yarn worker:prod`** ⚠️ CRITICAL
- [ ] Restart Policy: `On Failure`

**Networking:**
- [ ] Public Domain: NOT generated
- [ ] Internal only

**Environment Variables:**
- [ ] `SERVER_URL=${{twenty-server.RAILWAY_PUBLIC_DOMAIN}}`
- [ ] `APP_SECRET=<same-as-server>`
- [ ] `PG_DATABASE_URL=${{Postgres.DATABASE_URL}}`
- [ ] `REDIS_URL=${{Redis.REDIS_URL}}`
- [ ] `DISABLE_DB_MIGRATIONS=true` ⚠️
- [ ] `DISABLE_CRON_JOBS_REGISTRATION=true` ⚠️
- [ ] `STORAGE_TYPE=local`

---

## 9. Common Configuration Mistakes

### ❌ Mistake 1: Custom start command on server
```yaml
# Server - WRONG
Start Command: node dist/src/main
```

**Why wrong?**
- The entrypoint.sh needs to run first
- Custom start command bypasses the entrypoint
- Database migrations won't run

**Correct:**
```yaml
# Server - CORRECT
Start Command: (empty - use Dockerfile default)
```

### ❌ Mistake 2: No start command on worker
```yaml
# Worker - WRONG
Start Command: (empty)
```

**Why wrong?**
- Will start web server instead of worker
- No background jobs will be processed

**Correct:**
```yaml
# Worker - CORRECT
Start Command: yarn worker:prod
```

### ❌ Mistake 3: Both services running migrations
```yaml
# Server
DISABLE_DB_MIGRATIONS=false

# Worker - WRONG
DISABLE_DB_MIGRATIONS=false
```

**Why wrong?**
- Race conditions
- Migration conflicts
- Database corruption possible

**Correct:**
```yaml
# Server
DISABLE_DB_MIGRATIONS=false

# Worker - CORRECT
DISABLE_DB_MIGRATIONS=true
```

### ❌ Mistake 4: Using image instead of building from repo
```yaml
# WRONG for local development
Source: Docker Image
Image: twentycrm/twenty:latest
```

**Why wrong (for your use case)?**
- Can't test local changes
- Not using your repository code

**Correct:**
```yaml
# CORRECT for local development
Source: GitHub Repository
Builder: DOCKERFILE
Dockerfile Path: packages/twenty-docker/twenty/Dockerfile
```

---

## 10. Deployment Flow Explained

### When Server Deploys:

```
1. Railway clones your repo
   ↓
2. Runs Docker build (5-10 min)
   ↓
3. Builds backend (nx run twenty-server:build)
   ↓
4. Builds frontend (nx build twenty-front)
   ↓
5. Creates final image with entrypoint.sh
   ↓
6. Starts container
   ↓
7. entrypoint.sh runs:
   - Checks DB schema
   - Runs migrations if needed
   - Registers cron jobs
   ↓
8. Executes CMD: node dist/src/main
   ↓
9. Server listens on port 3000
   ↓
10. Health check: GET /healthz
    ↓
11. Deployment successful ✅
```

### When Worker Deploys:

```
1. Railway clones your repo (same as server)
   ↓
2. Runs same Docker build
   ↓
3. Creates same image
   ↓
4. Starts container
   ↓
5. entrypoint.sh runs:
   - Skips migrations (DISABLE_DB_MIGRATIONS=true)
   - Skips cron jobs (DISABLE_CRON_JOBS_REGISTRATION=true)
   ↓
6. Executes OVERRIDE CMD: yarn worker:prod
   ↓
7. Worker connects to Redis
   ↓
8. Starts processing jobs
   ↓
9. Deployment successful ✅
```

---

## 11. Expected Build Output

### Successful Server Build:
```
Building Dockerfile...
Step 1/25 : FROM node:24-alpine AS common-deps
...
Step 20/25 : RUN npx nx run twenty-server:build
...
Step 31/25 : CMD ["node", "dist/src/main"]
Successfully built image

Deploying...
Database setup and migrations are disabled, skipping...
OR
Running database setup and migrations...
Successfully migrated DB!

Registering background sync jobs...
Successfully registered all background sync jobs!

[Nest] Application is running on: http://[::]:3000
```

### Successful Worker Build:
```
Building Dockerfile...
(same as server build)
Successfully built image

Deploying...
Database setup and migrations are disabled, skipping...
Cron job registration is disabled, skipping...

[Nest] Worker started successfully
[Nest] Connected to Redis
[Nest] Processing jobs from queue...
```

---

## 12. Recommended Actions

### Before Redeploying Server:

1. **Verify GitHub Connection**
   - Ensure Railway is connected to your repository
   - Check the correct branch is selected

2. **Check Build Settings**
   ```
   ✓ Builder: DOCKERFILE
   ✓ Dockerfile Path: packages/twenty-docker/twenty/Dockerfile
   ✓ Root Directory: / (or empty)
   ```

3. **Verify Start Command**
   ```
   Server Start Command: (EMPTY)
   NOT: node dist/src/main
   NOT: yarn start:prod
   ```

4. **Check Environment Variables**
   - All required variables present
   - `DISABLE_DB_MIGRATIONS=false`
   - `DISABLE_CRON_JOBS_REGISTRATION=false`

5. **Verify Dependencies**
   - PostgreSQL service is healthy
   - Redis service is healthy

### Deployment Commands:

**Option 1: Via Railway CLI**
```bash
# Link to server service (interactive selection)
railway service

# Then deploy
railway up
```

**Option 2: Via Service ID (if known)**
```bash
railway up --service <server-service-id>
```

**Option 3: Via Dashboard**
- Go to Server service → Deployments → New Deployment

---

## 13. Monitoring Deployment

### What to Watch:

**Build Phase (5-10 minutes):**
- [ ] Dependencies installing
- [ ] Backend building
- [ ] Frontend building
- [ ] Docker image created

**Deploy Phase (2-5 minutes):**
- [ ] Container starting
- [ ] Entrypoint script running
- [ ] Migrations executing (if needed)
- [ ] Cron jobs registering
- [ ] Server starting on port 3000
- [ ] Health check passing

**Health Check:**
```bash
# Test manually:
curl https://your-domain.railway.app/healthz

# Expected response:
{"status":"ok"}
```

---

## 14. Troubleshooting Guide

### Build Fails

**Symptom**: Build fails during Docker build phase

**Check:**
1. Dockerfile path is correct
2. All required files exist in repository
3. package.json files are valid
4. Dependencies can be installed

**Solution:**
```bash
# Test build locally:
docker build -f packages/twenty-docker/twenty/Dockerfile -t twenty-test .
```

### Migration Fails

**Symptom**: "Migration failed" in logs

**Check:**
1. `PG_DATABASE_URL` is correct
2. PostgreSQL service is running
3. Database is accessible
4. No other service is running migrations simultaneously

**Solution:**
- Ensure only server has `DISABLE_DB_MIGRATIONS=false`
- Check database connection string format

### Server Won't Start

**Symptom**: Container starts but server doesn't listen

**Check:**
1. Port 3000 is not blocked
2. `PORT` environment variable is set
3. No errors in application logs
4. Redis is accessible

**Solution:**
- Check logs for specific error messages
- Verify all environment variables are set

### Health Check Fails

**Symptom**: "Deployment unhealthy" message

**Check:**
1. Health check path is `/healthz`
2. Health check timeout is at least 100 seconds
3. Server is actually starting
4. No network issues

**Solution:**
```bash
# View logs:
railway logs --service <server-service-id>

# Check for "Application is running" message
```

---

## 15. Summary & Recommendations

### ✅ Correct Configuration Summary

**Server:**
- Source: GitHub Repository
- Build: Dockerfile at `packages/twenty-docker/twenty/Dockerfile`
- Start Command: **(EMPTY)** - uses Dockerfile default
- Health Check: `/healthz` with 100s timeout
- Migrations: **ENABLED** (`DISABLE_DB_MIGRATIONS=false`)
- Cron Jobs: **ENABLED** (`DISABLE_CRON_JOBS_REGISTRATION=false`)

**Worker:**
- Source: Same GitHub Repository
- Build: Same Dockerfile
- Start Command: **`yarn worker:prod`** (CRITICAL OVERRIDE)
- Migrations: **DISABLED** (`DISABLE_DB_MIGRATIONS=true`)
- Cron Jobs: **DISABLED** (`DISABLE_CRON_JOBS_REGISTRATION=true`)

### 🎯 Key Takeaways

1. **DO NOT set a custom start command on the server** - let the Dockerfile handle it
2. **DO set a custom start command on the worker** - `yarn worker:prod`
3. **Only the server should run migrations and cron jobs**
4. **Both services build from the same Dockerfile but run different commands**
5. **The entrypoint.sh is critical** - it handles migrations before starting the app

### 📋 Pre-Deployment Checklist

Before clicking "Deploy" on the server:

- [ ] GitHub repository connected
- [ ] Dockerfile path: `packages/twenty-docker/twenty/Dockerfile`
- [ ] Start command: **(EMPTY)**
- [ ] Health check: `/healthz` + 100s timeout
- [ ] All environment variables set correctly
- [ ] PostgreSQL and Redis are healthy
- [ ] Worker is properly configured with `yarn worker:prod`

---

## 16. Next Steps

1. **Review this document thoroughly**
2. **Check your Railway dashboard configuration**
3. **Verify each setting matches the recommendations**
4. **If everything looks good, proceed with deployment**
5. **Monitor build and deployment logs carefully**
6. **Test the application after deployment**

---

## References

- Railway Template: https://railway.com/template/nAL3hA
- Twenty CRM Docs: https://twenty.com/developers
- Railway Docs: https://docs.railway.com
- Dockerfile: `packages/twenty-docker/twenty/Dockerfile`
- Entrypoint: `packages/twenty-docker/twenty/entrypoint.sh`
- Scripts: `packages/twenty-server/scripts/`

---

**Document Created**: October 31, 2025
**Analysis Status**: ✅ Complete
**Ready for Deployment**: ✅ Yes (after verification)
