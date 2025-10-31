# Server vs Worker Configuration Comparison

**Critical differences between Twenty Server and Twenty Worker services on Railway**

---

## Side-by-Side Configuration

| Setting | Twenty Server (Web App) | Twenty Worker (Background Jobs) |
|---------|------------------------|--------------------------------|
| **Service Name** | `twenty-server` or `twenty` | `twenty-worker` |
| **Repository** | Your Twenty CRM repo | **SAME** repository |
| **Branch** | `main` (or default) | **SAME** branch |
| **Root Directory** | `/` | `/` |
| **Dockerfile Path** | `packages/twenty-docker/twenty/Dockerfile` | `packages/twenty-docker/twenty/Dockerfile` |

---

## Build & Deploy Settings

| Setting | Server | Worker |
|---------|--------|--------|
| **Custom Start Command** | (empty/default) | `yarn worker:prod` ⚠️ |
| **Health Check Path** | `/healthz` | (none) |
| **Health Check Timeout** | `100` seconds | (none) |
| **Restart Policy** | On Failure | On Failure |

---

## Networking

| Setting | Server | Worker |
|---------|--------|--------|
| **Public Domain** | ✅ **REQUIRED** - Generate | ❌ **NOT NEEDED** |
| **Port** | `3000` | (internal only) |
| **External Access** | Yes | No |

---

## Environment Variables

### IDENTICAL Variables (must be same for both)

```bash
# These MUST match exactly:
APP_SECRET=<same-random-string-for-both>
PG_DATABASE_URL=${{Postgres.DATABASE_URL}}
REDIS_URL=${{Redis.REDIS_URL}}
STORAGE_TYPE=local  # or s3 (must match)
STORAGE_LOCAL_PATH=.local-storage  # must match
```

### DIFFERENT Variables (critical!)

| Variable | Server Value | Worker Value |
|----------|--------------|--------------|
| `SERVER_URL` | `${{RAILWAY_PUBLIC_DOMAIN}}` | `${{twenty-server.RAILWAY_PUBLIC_DOMAIN}}` |
| `PORT` | `3000` | *(not needed)* |
| `DISABLE_DB_MIGRATIONS` | `false` ⚠️ | `true` ⚠️ |
| `DISABLE_CRON_JOBS_REGISTRATION` | `false` ⚠️ | `true` ⚠️ |

---

## Complete Variable Lists

### Twenty Server Variables

```bash
# Core
PORT=3000
SERVER_URL=${{RAILWAY_PUBLIC_DOMAIN}}
APP_SECRET=a7f4e9c2d8b3f6a1e5c7d9b2f4a6e8c0d2f4a6e8c0d2f4a6e8c0d2f4a6e8c0

# Database
PG_DATABASE_URL=${{Postgres.DATABASE_URL}}

# Cache
REDIS_URL=${{Redis.REDIS_URL}}

# Server Behavior (IMPORTANT!)
DISABLE_DB_MIGRATIONS=false
DISABLE_CRON_JOBS_REGISTRATION=false

# Storage
STORAGE_TYPE=local
STORAGE_LOCAL_PATH=.local-storage
```

### Twenty Worker Variables

```bash
# Core
SERVER_URL=${{twenty-server.RAILWAY_PUBLIC_DOMAIN}}
APP_SECRET=a7f4e9c2d8b3f6a1e5c7d9b2f4a6e8c0d2f4a6e8c0d2f4a6e8c0d2f4a6e8c0

# Database
PG_DATABASE_URL=${{Postgres.DATABASE_URL}}

# Cache
REDIS_URL=${{Redis.REDIS_URL}}

# Worker Behavior (IMPORTANT!)
DISABLE_DB_MIGRATIONS=true
DISABLE_CRON_JOBS_REGISTRATION=true

# Storage (must match server)
STORAGE_TYPE=local
STORAGE_LOCAL_PATH=.local-storage
```

---

## Why These Differences Matter

### 1. Custom Start Command

**Server**: Uses default Dockerfile CMD → `node dist/src/main`
- Starts the NestJS web application
- Serves frontend + GraphQL API
- Listens on port 3000

**Worker**: Override with `yarn worker:prod` → `node dist/src/queue-worker/queue-worker`
- Starts the background job processor
- Processes BullMQ jobs from Redis
- No HTTP server needed

### 2. DISABLE_DB_MIGRATIONS

**Server** = `false`: ✅ Runs migrations on startup
- Executes database schema changes
- Sets up initial database structure
- Runs `yarn database:init:prod`

**Worker** = `true`: ❌ Skips migrations
- Prevents migration conflicts
- Only server should modify DB schema
- Avoids race conditions

### 3. DISABLE_CRON_JOBS_REGISTRATION

**Server** = `false`: ✅ Registers cron jobs
- Schedules periodic background tasks
- Sets up job definitions in BullMQ
- Only needs to happen once

**Worker** = `true`: ❌ Skips registration
- Prevents duplicate job definitions
- Just processes jobs, doesn't create them
- Server already registered them

### 4. SERVER_URL Reference

**Server**: `${{RAILWAY_PUBLIC_DOMAIN}}`
- References its own public domain
- Railway auto-provides this variable
- Used for generating callback URLs

**Worker**: `${{twenty-server.RAILWAY_PUBLIC_DOMAIN}}`
- References the SERVER's domain
- Needs to know where the API is
- Cross-service variable reference

### 5. Public Domain

**Server**: ✅ Required
- Users access the app here
- Handles HTTP/HTTPS traffic
- Frontend served from here

**Worker**: ❌ Not needed
- Internal service only
- No user-facing interface
- Communicates via Redis/DB only

---

## Common Mistakes to Avoid

### ❌ WRONG - Both services with same migration setting
```bash
# Server
DISABLE_DB_MIGRATIONS=false

# Worker (WRONG!)
DISABLE_DB_MIGRATIONS=false  # ❌ Will cause conflicts!
```

### ✅ CORRECT - Only server runs migrations
```bash
# Server
DISABLE_DB_MIGRATIONS=false

# Worker
DISABLE_DB_MIGRATIONS=true  # ✅ Correct!
```

---

### ❌ WRONG - Different APP_SECRET values
```bash
# Server
APP_SECRET=abc123...

# Worker (WRONG!)
APP_SECRET=xyz789...  # ❌ Must be identical!
```

### ✅ CORRECT - Same APP_SECRET for both
```bash
# Server
APP_SECRET=a7f4e9c2d8b3f6a1e5c7d9b2f4a6e8c0d2f4a6e8c0d2f4a6e8c0d2f4a6e8c0

# Worker
APP_SECRET=a7f4e9c2d8b3f6a1e5c7d9b2f4a6e8c0d2f4a6e8c0d2f4a6e8c0d2f4a6e8c0  # ✅ Same!
```

---

### ❌ WRONG - Worker without custom start command
```bash
# Worker Settings
Custom Start Command: (empty)  # ❌ Will start web server instead!
```

### ✅ CORRECT - Worker with proper start command
```bash
# Worker Settings
Custom Start Command: yarn worker:prod  # ✅ Starts queue worker!
```

---

### ❌ WRONG - Different storage configuration
```bash
# Server
STORAGE_TYPE=local

# Worker (WRONG!)
STORAGE_TYPE=s3  # ❌ Must match server!
```

### ✅ CORRECT - Matching storage configuration
```bash
# Server
STORAGE_TYPE=local

# Worker
STORAGE_TYPE=local  # ✅ Same as server!
```

---

## Quick Validation Checklist

### Before Deploying - Server
- [ ] Dockerfile path is correct
- [ ] Public domain generated
- [ ] Health check path set to `/healthz`
- [ ] `PORT=3000` is set
- [ ] `SERVER_URL=${{RAILWAY_PUBLIC_DOMAIN}}`
- [ ] `DISABLE_DB_MIGRATIONS=false`
- [ ] `DISABLE_CRON_JOBS_REGISTRATION=false`
- [ ] `APP_SECRET` is a secure random string
- [ ] Database and Redis variables reference correctly

### Before Deploying - Worker
- [ ] Dockerfile path is correct (same as server)
- [ ] Custom start command: `yarn worker:prod`
- [ ] NO public domain generated
- [ ] `SERVER_URL=${{twenty-server.RAILWAY_PUBLIC_DOMAIN}}`
- [ ] `DISABLE_DB_MIGRATIONS=true`
- [ ] `DISABLE_CRON_JOBS_REGISTRATION=true`
- [ ] `APP_SECRET` matches server EXACTLY
- [ ] Storage settings match server EXACTLY
- [ ] Database and Redis variables reference correctly

### After Deployment - Server
- [ ] Logs show: "Successfully migrated DB!"
- [ ] Logs show: "Application is running on: http://[::]:3000"
- [ ] Health check is passing (green indicator)
- [ ] Service is healthy
- [ ] Can access at public domain
- [ ] `/healthz` endpoint returns 200 OK

### After Deployment - Worker
- [ ] Logs show successful worker startup
- [ ] No migration-related errors
- [ ] Connected to Redis successfully
- [ ] Connected to database successfully
- [ ] Service is healthy
- [ ] No "command not found" errors

---

## Debugging Based on Logs

### Server Log Indicators

**✅ GOOD Server Logs:**
```
Database setup and migrations...
Successfully migrated DB!
Registering background sync jobs...
Successfully registered all background sync jobs!
Application is running on: http://[::]:3000
```

**❌ BAD Server Logs:**
```
Error: connect ECONNREFUSED (database connection failed)
→ Check: PG_DATABASE_URL

Error: Redis connection failed
→ Check: REDIS_URL

Health check failed
→ Check: Health check path and timeout
```

### Worker Log Indicators

**✅ GOOD Worker Logs:**
```
Database setup and migrations are disabled, skipping...
Cron job registration is disabled, skipping...
Worker started successfully
Connected to Redis
Processing jobs...
```

**❌ BAD Worker Logs:**
```
yarn: command not found
→ Check: Custom start command is set to "yarn worker:prod"

Database migration conflicts
→ Check: DISABLE_DB_MIGRATIONS=true

Multiple cron job registrations detected
→ Check: DISABLE_CRON_JOBS_REGISTRATION=true
```

---

## Summary Table

| Aspect | Server | Worker | Must Match? |
|--------|--------|--------|-------------|
| Repository | twenty-crm | twenty-crm | ✅ Yes |
| Dockerfile Path | `packages/.../Dockerfile` | `packages/.../Dockerfile` | ✅ Yes |
| Start Command | (default) | `yarn worker:prod` | ❌ No |
| Public Domain | Required | Not needed | ❌ No |
| APP_SECRET | `<random>` | `<random>` | ✅ **MUST** be same |
| PG_DATABASE_URL | `${{Postgres...}}` | `${{Postgres...}}` | ✅ Yes |
| REDIS_URL | `${{Redis...}}` | `${{Redis...}}` | ✅ Yes |
| STORAGE_TYPE | `local` or `s3` | `local` or `s3` | ✅ **MUST** match |
| SERVER_URL | Own domain | Server's domain | ❌ No |
| DISABLE_DB_MIGRATIONS | `false` | `true` | ❌ **MUST** differ |
| DISABLE_CRON_JOBS_REGISTRATION | `false` | `true` | ❌ **MUST** differ |

---

## Copy-Paste Templates

### Server Environment Variables Template
```bash
PORT=3000
SERVER_URL=${{RAILWAY_PUBLIC_DOMAIN}}
APP_SECRET=REPLACE_WITH_RANDOM_STRING
PG_DATABASE_URL=${{Postgres.DATABASE_URL}}
REDIS_URL=${{Redis.REDIS_URL}}
DISABLE_DB_MIGRATIONS=false
DISABLE_CRON_JOBS_REGISTRATION=false
STORAGE_TYPE=local
STORAGE_LOCAL_PATH=.local-storage
```

### Worker Environment Variables Template
```bash
SERVER_URL=${{twenty-server.RAILWAY_PUBLIC_DOMAIN}}
APP_SECRET=SAME_AS_SERVER
PG_DATABASE_URL=${{Postgres.DATABASE_URL}}
REDIS_URL=${{Redis.REDIS_URL}}
DISABLE_DB_MIGRATIONS=true
DISABLE_CRON_JOBS_REGISTRATION=true
STORAGE_TYPE=local
STORAGE_LOCAL_PATH=.local-storage
```

### Generate APP_SECRET Command
```bash
openssl rand -hex 32
```

---

**Remember**: The worker is essentially running the SAME code as the server, but with:
1. A different entry point (queue worker instead of web server)
2. Different startup behavior (no migrations, no cron registration)
3. No public access (internal only)

This allows both services to work together harmoniously! 🚀
