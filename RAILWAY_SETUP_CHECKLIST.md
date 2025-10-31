# Railway Setup Checklist - Twenty CRM

Quick reference for configuring your Railway project.

---

## 🎯 Services Needed (4 Total)

```
[ ] 1. PostgreSQL 16
[ ] 2. Redis 8.x
[ ] 3. Twenty Server
[ ] 4. Twenty Worker
```

---

## 📦 Service 1: PostgreSQL

**Add:** + New → Database → PostgreSQL

```
✓ Auto-configured
✓ No settings needed
```

---

## 📦 Service 2: Redis

**Add:** + New → Database → Redis

```
✓ Auto-configured
✓ No settings needed
```

---

## 📦 Service 3: Twenty Server (Main App)

**Add:** + New → GitHub Repo → Select your Twenty CRM repo

### ⚙️ Settings → Build
```
Dockerfile Path: packages/twenty-docker/twenty/Dockerfile
```

### ⚙️ Settings → Deploy
```
Health Check Path: /healthz
Health Check Timeout: 100
Restart Policy: On Failure
```

### 🌐 Settings → Networking
```
✓ Generate Domain
✓ Note your domain URL
```

### 🔐 Variables
```bash
# Copy these EXACTLY:
PORT=3000
SERVER_URL=${{RAILWAY_PUBLIC_DOMAIN}}
APP_SECRET=<generate-using-command-below>
PG_DATABASE_URL=${{Postgres.DATABASE_URL}}
REDIS_URL=${{Redis.REDIS_URL}}
DISABLE_DB_MIGRATIONS=false
DISABLE_CRON_JOBS_REGISTRATION=false
STORAGE_TYPE=local
STORAGE_LOCAL_PATH=.local-storage
```

**Generate APP_SECRET:**
```bash
openssl rand -hex 32
```
Copy output and paste as APP_SECRET value.

---

## 📦 Service 4: Twenty Worker (Background Jobs)

**Add:** + New → GitHub Repo → Select **SAME** repo

### ⚙️ Settings → Build
```
Dockerfile Path: packages/twenty-docker/twenty/Dockerfile
```

### ⚙️ Settings → Deploy
```
Custom Start Command: yarn worker:prod   ⚠️ CRITICAL!
Restart Policy: On Failure
```

### 🌐 Settings → Networking
```
✗ DO NOT generate domain (not needed)
```

### 🔐 Variables
```bash
# Copy these EXACTLY (note the differences!):
SERVER_URL=${{twenty-server.RAILWAY_PUBLIC_DOMAIN}}
APP_SECRET=<use-SAME-secret-as-server>
PG_DATABASE_URL=${{Postgres.DATABASE_URL}}
REDIS_URL=${{Redis.REDIS_URL}}
DISABLE_DB_MIGRATIONS=true          ⚠️ true (not false!)
DISABLE_CRON_JOBS_REGISTRATION=true ⚠️ true (not false!)
STORAGE_TYPE=local
STORAGE_LOCAL_PATH=.local-storage
```

---

## ⚠️ Critical Differences

| Variable | Server | Worker |
|----------|--------|--------|
| `DISABLE_DB_MIGRATIONS` | **false** | **true** |
| `DISABLE_CRON_JOBS_REGISTRATION` | **false** | **true** |
| `SERVER_URL` | `${{RAILWAY_PUBLIC_DOMAIN}}` | `${{twenty-server.RAILWAY_PUBLIC_DOMAIN}}` |
| Custom Start Command | (none) | `yarn worker:prod` |
| Public Domain | ✓ Generate | ✗ Not needed |

---

## 🚀 Deployment Order

1. ✅ Add PostgreSQL
2. ✅ Add Redis
3. ✅ Configure & Deploy Server
4. ✅ Configure & Deploy Worker

---

## ✅ Final Checklist

### Before Deploying
- [ ] Generated unique APP_SECRET (32+ chars)
- [ ] Used SAME APP_SECRET for both Server and Worker
- [ ] Set Server: DISABLE_DB_MIGRATIONS=false
- [ ] Set Worker: DISABLE_DB_MIGRATIONS=true
- [ ] Set Server: DISABLE_CRON_JOBS_REGISTRATION=false
- [ ] Set Worker: DISABLE_CRON_JOBS_REGISTRATION=true
- [ ] Set Worker custom start command: yarn worker:prod
- [ ] Generated public domain for Server only

### After Deploying
- [ ] PostgreSQL shows green/healthy
- [ ] Redis shows green/healthy
- [ ] Server deployment successful
- [ ] Worker deployment successful
- [ ] Server logs show: "Successfully migrated DB!"
- [ ] Server logs show: "Application is running on: http://[::]:3000"
- [ ] Worker logs show successful startup
- [ ] Can access app at your domain
- [ ] Health check passing: https://your-domain/healthz

---

## 🐛 Quick Troubleshooting

| Problem | Solution |
|---------|----------|
| Server won't start | Check DB & Redis are running, verify env vars |
| Worker won't start | Verify custom start command: `yarn worker:prod` |
| Migration errors | Only server should have DISABLE_DB_MIGRATIONS=false |
| "yarn not found" | Check Dockerfile path is correct |
| Variables not loading | Use syntax: `${{ServiceName.VARIABLE}}` |
| Health check fails | Increase timeout to 100s, check /healthz path |

---

## 📊 Expected Timeline

- Database setup: **~2 minutes**
- Server first deploy: **~5-10 minutes**
- Worker deploy: **~5 minutes**
- **Total: ~15-20 minutes**

---

## 🎉 Success Indicators

✅ All 4 services showing green/healthy
✅ Server accessible at your domain
✅ Can create account and login
✅ No errors in deployment logs
✅ /healthz returns 200 OK

---

## 📚 Full Documentation

See `RAILWAY_CONFIGURATION_GUIDE.md` for complete details.

---

## 💰 Cost Estimate

- **Hobby Plan**: $5/month (good for testing)
- **Pro Plan**: $37-60/month (recommended for production)

---

**Pro Tip:** Use Railway's template for one-click deploy:
https://railway.com/template/nAL3hA
