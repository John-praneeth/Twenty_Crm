# Twenty CRM - Railway Deployment Guide

This guide will help you deploy Twenty CRM to Railway.app.

## Prerequisites

- Railway account ([railway.app](https://railway.app))
- Railway CLI (optional): `npm install -g @railway/cli`
- Git repository connected to Railway

## Architecture Overview

Twenty CRM requires 4 services on Railway:

1. **PostgreSQL Database** (Plugin)
2. **Redis Cache** (Plugin)
3. **Twenty Server** (Main web application)
4. **Twenty Worker** (Background job processor)

---

## Deployment Steps

### Step 1: Create a New Railway Project

1. Go to [railway.app](https://railway.app) and create a new project
2. Choose "Deploy from GitHub repo"
3. Connect your GitHub account and select this repository

### Step 2: Add PostgreSQL Database

1. In your Railway project, click **"+ New"**
2. Select **"Database" → "Add PostgreSQL"**
3. Railway will automatically provision a PostgreSQL 16 instance
4. Note: Railway will automatically create a `DATABASE_URL` environment variable

### Step 3: Add Redis Cache

1. Click **"+ New"** again
2. Select **"Database" → "Add Redis"**
3. Railway will automatically provision a Redis instance
4. Note: Railway will automatically create a `REDIS_URL` environment variable

### Step 4: Deploy the Server Service

1. Click **"+ New"** → **"GitHub Repo"**
2. Select your Twenty CRM repository
3. Railway will detect the Dockerfile automatically
4. Configure the service:
   - **Name**: `twenty-server`
   - **Root Directory**: Leave as `/` (root)
   - **Dockerfile Path**: `packages/twenty-docker/twenty/Dockerfile`

#### Configure Server Environment Variables

Add these environment variables to the server service:

```bash
# Core Settings
NODE_PORT=3000
SERVER_URL=${{RAILWAY_PUBLIC_DOMAIN}}
APP_SECRET=<generate-a-random-32-character-string>

# Database (Railway will auto-populate these)
PG_DATABASE_URL=${{Postgres.DATABASE_URL}}

# Redis (Railway will auto-populate this)
REDIS_URL=${{Redis.REDIS_URL}}

# Server-specific settings
DISABLE_DB_MIGRATIONS=false
DISABLE_CRON_JOBS_REGISTRATION=false

# Storage (local by default)
STORAGE_TYPE=local
```

5. Under **Settings** → **Networking**, generate a public domain
6. Click **"Deploy"**

### Step 5: Deploy the Worker Service

1. Click **"+ New"** → **"GitHub Repo"**
2. Select your Twenty CRM repository again
3. Configure the service:
   - **Name**: `twenty-worker`
   - **Root Directory**: Leave as `/` (root)
   - **Dockerfile Path**: `packages/twenty-docker/twenty/Dockerfile`

#### Configure Worker Environment Variables

Add these environment variables to the worker service:

```bash
# Core Settings
SERVER_URL=${{twenty-server.RAILWAY_PUBLIC_DOMAIN}}
APP_SECRET=<same-random-string-as-server>

# Database (Railway will auto-populate these)
PG_DATABASE_URL=${{Postgres.DATABASE_URL}}

# Redis (Railway will auto-populate this)
REDIS_URL=${{Redis.REDIS_URL}}

# Worker-specific settings (IMPORTANT!)
DISABLE_DB_MIGRATIONS=true
DISABLE_CRON_JOBS_REGISTRATION=true

# Storage (must match server)
STORAGE_TYPE=local
```

#### Set Custom Start Command for Worker

1. Go to **Settings** → **Deploy**
2. Under **Custom Start Command**, enter:
   ```bash
   yarn worker:prod
   ```
3. Click **"Deploy"**

---

## Generate APP_SECRET

You need a secure random string for `APP_SECRET`. Generate one using:

```bash
# Using OpenSSL (Mac/Linux)
openssl rand -hex 16

# Using Node.js
node -e "console.log(require('crypto').randomBytes(16).toString('hex'))"

# Using Python
python3 -c "import secrets; print(secrets.token_hex(16))"
```

Use the same `APP_SECRET` for both server and worker services.

---

## Service Dependencies

Configure service dependencies to ensure proper startup order:

1. **Server** depends on:
   - PostgreSQL ✓
   - Redis ✓

2. **Worker** depends on:
   - PostgreSQL ✓
   - Redis ✓
   - Server ✓

Railway handles this automatically when you reference variables like `${{Postgres.DATABASE_URL}}`.

---

## Environment Variables Reference

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `NODE_PORT` | Port for the server | `3000` |
| `SERVER_URL` | Public URL of your app | `https://your-app.railway.app` |
| `APP_SECRET` | Secret key for sessions/JWT | `32-character-random-string` |
| `PG_DATABASE_URL` | PostgreSQL connection string | Auto-provided by Railway |
| `REDIS_URL` | Redis connection string | Auto-provided by Railway |

### Storage Options

**Local Storage (Default)**
```bash
STORAGE_TYPE=local
```

**AWS S3 Storage**
```bash
STORAGE_TYPE=s3
STORAGE_S3_REGION=us-east-1
STORAGE_S3_NAME=your-bucket-name
STORAGE_S3_ENDPOINT=https://s3.amazonaws.com
AWS_ACCESS_KEY_ID=your-access-key
AWS_SECRET_ACCESS_KEY=your-secret-key
```

### Optional Integrations

See `.env.railway.example` for:
- Email configuration (SMTP)
- Google OAuth & Calendar
- Microsoft OAuth & Calendar

---

## Monitoring & Logs

1. **View Logs**: Click on each service → **Logs** tab
2. **Metrics**: Railway provides CPU, Memory, and Network metrics
3. **Health Check**: The server has a `/healthz` endpoint

---

## Troubleshooting

### Server won't start

1. Check logs for error messages
2. Verify `DATABASE_URL` and `REDIS_URL` are correctly set
3. Ensure PostgreSQL and Redis services are running
4. Check that `SERVER_URL` matches your Railway domain

### Worker won't start

1. Verify the custom start command is set to `yarn worker:prod`
2. Ensure `DISABLE_DB_MIGRATIONS=true` and `DISABLE_CRON_JOBS_REGISTRATION=true`
3. Check that worker can connect to PostgreSQL and Redis
4. Verify `APP_SECRET` matches the server

### Database connection issues

1. Check if PostgreSQL service is healthy
2. Verify `PG_DATABASE_URL` format: `postgres://user:password@host:port/database`
3. Check Railway logs for connection errors

### Port binding issues

Railway dynamically assigns ports. Ensure your app listens on `process.env.PORT` or the configured `NODE_PORT`.

---

## Accessing Your Application

Once deployed:

1. Get your server's public domain from Railway
2. Open `https://your-app.railway.app` in your browser
3. You should see the Twenty CRM login page
4. Default credentials (if seed data was loaded):
   - Email: `admin@example.com`
   - Password: Check the logs or documentation

---

## Updating Your Deployment

Railway automatically deploys when you push to your connected Git branch.

**Manual Redeploy:**
1. Go to your service
2. Click **"Deploy"** → **"Redeploy"**

---

## Cost Estimation

Railway pricing (as of 2024):
- **Free Tier**: $5 credit/month (good for testing)
- **Pro Plan**: $20/month + usage
- **PostgreSQL**: ~$5-10/month
- **Redis**: ~$2-5/month
- **Server + Worker**: Based on usage

**Estimated monthly cost**: $27-35 for production use

---

## Production Recommendations

1. **Enable automatic backups** for PostgreSQL
2. **Set up monitoring** and alerts
3. **Configure custom domain** in Railway settings
4. **Enable HTTPS** (Railway provides this automatically)
5. **Set resource limits** to control costs
6. **Configure email** for notifications and password resets
7. **Set up OAuth** for Google/Microsoft if needed
8. **Use S3 storage** for file uploads in production

---

## Alternative: One-Click Deploy (Coming Soon)

You can also create a one-click deploy button:

[![Deploy on Railway](https://railway.app/button.svg)](https://railway.app/template/...)

*Note: Template needs to be created and published on Railway*

---

## Support

- Twenty CRM Docs: [twenty.com/developers](https://twenty.com/developers)
- Railway Docs: [docs.railway.app](https://docs.railway.app)
- Twenty Discord: [discord.gg/cx5n4Jzs57](https://discord.gg/cx5n4Jzs57)
- Railway Discord: [discord.gg/railway](https://discord.gg/railway)

---

## Next Steps

After deployment:
1. Configure your workspace
2. Customize objects and fields
3. Set up integrations (Google, Microsoft)
4. Configure email settings
5. Invite team members
6. Set up workflows and automation

Happy deploying!
