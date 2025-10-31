# Twenty CRM - Railway Quick Start

## TL;DR - Deploy in 10 Minutes

### 1. Prerequisites
- Railway account at [railway.app](https://railway.app)
- This repo pushed to GitHub

### 2. Create Railway Project
```bash
# Option A: Using Railway CLI
railway login
railway init
railway up

# Option B: Using Web UI
# Go to railway.app → New Project → Deploy from GitHub
```

### 3. Add Services (in this order)

#### A. Add PostgreSQL
1. Click **"+ New"** → **"Database"** → **"PostgreSQL"**
2. Done! Railway auto-configures.

#### B. Add Redis
1. Click **"+ New"** → **"Database"** → **"Redis"**
2. Done! Railway auto-configures.

#### C. Deploy Server
1. Click **"+ New"** → **"GitHub Repo"** → Select this repo
2. **Service Name**: `twenty-server`
3. **Settings** → **Dockerfile Path**: `packages/twenty-docker/twenty/Dockerfile`
4. **Settings** → **Networking** → Generate Domain
5. Add Environment Variables:
```bash
NODE_PORT=3000
SERVER_URL=${{RAILWAY_PUBLIC_DOMAIN}}
APP_SECRET=<generate-random-32-chars>
PG_DATABASE_URL=${{Postgres.DATABASE_URL}}
REDIS_URL=${{Redis.REDIS_URL}}
STORAGE_TYPE=local
```
6. Click **"Deploy"**

#### D. Deploy Worker
1. Click **"+ New"** → **"GitHub Repo"** → Select this repo again
2. **Service Name**: `twenty-worker`
3. **Settings** → **Dockerfile Path**: `packages/twenty-docker/twenty/Dockerfile`
4. **Settings** → **Custom Start Command**: `yarn worker:prod`
5. Add Environment Variables:
```bash
SERVER_URL=${{twenty-server.RAILWAY_PUBLIC_DOMAIN}}
APP_SECRET=<same-as-server>
PG_DATABASE_URL=${{Postgres.DATABASE_URL}}
REDIS_URL=${{Redis.REDIS_URL}}
DISABLE_DB_MIGRATIONS=true
DISABLE_CRON_JOBS_REGISTRATION=true
STORAGE_TYPE=local
```
6. Click **"Deploy"**

### 4. Generate APP_SECRET
```bash
openssl rand -hex 16
# OR
node -e "console.log(require('crypto').randomBytes(16).toString('hex'))"
```
Use the same secret for both server and worker!

### 5. Access Your App
1. Wait for deployment to complete (~5-10 minutes)
2. Go to your Railway domain (e.g., `https://your-app.railway.app`)
3. Create your account and start using Twenty CRM!

---

## Service Architecture

```
┌─────────────────┐
│   PostgreSQL    │ ← Database
└────────┬────────┘
         │
         ├─────────┐
         │         │
┌────────▼──────┐  │
│ Twenty Server │  │ ← Web App (Frontend + API)
│ Port: 3000    │  │
└────────┬──────┘  │
         │         │
         │    ┌────▼────────┐
         │    │   Redis     │ ← Cache & Queue
         │    └────┬────────┘
         │         │
         │    ┌────▼──────────┐
         └────► Twenty Worker │ ← Background Jobs
              └───────────────┘
```

---

## Costs (Estimated)

**Hobby Tier:**
- Free: $5 credit/month
- Good for: Testing only

**Production Tier:**
- Railway Pro: $20/month base
- PostgreSQL: $5-10/month
- Redis: $2-5/month
- Compute: $5-15/month
- **Total: ~$32-50/month**

---

## Troubleshooting

### Server won't start?
- Check PostgreSQL and Redis are running ✓
- Verify `DATABASE_URL` is set ✓
- Check logs for errors ✓

### Worker won't start?
- Verify custom start command: `yarn worker:prod` ✓
- Ensure `DISABLE_DB_MIGRATIONS=true` ✓
- Check `APP_SECRET` matches server ✓

### Can't connect?
- Verify public domain is generated ✓
- Check server logs for startup errors ✓
- Wait 5-10 mins for first deployment ✓

---

## Next Steps

1. ✓ Access your app at your Railway domain
2. ✓ Create your admin account
3. ✓ Customize your workspace
4. ✓ Invite team members
5. ✓ Configure integrations (optional)

---

## Full Documentation

See `RAILWAY_DEPLOYMENT.md` for:
- Detailed configuration options
- Email setup (SMTP)
- OAuth integrations (Google, Microsoft)
- S3 storage configuration
- Production best practices
- Advanced troubleshooting

---

## Need Help?

- **Twenty Docs**: [twenty.com/developers](https://twenty.com/developers)
- **Railway Docs**: [docs.railway.app](https://docs.railway.app)
- **Twenty Discord**: [discord.gg/cx5n4Jzs57](https://discord.gg/cx5n4Jzs57)

---

**Quick Deploy Time**: ~10 minutes
**First Boot Time**: ~5-10 minutes
**Monthly Cost**: ~$32-50 (production)

Happy deploying! 🚀
