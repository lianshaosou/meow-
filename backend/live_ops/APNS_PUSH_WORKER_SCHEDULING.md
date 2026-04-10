# APNs Worker Scheduling Guide

This document provides production scheduling patterns for `apns-push-worker`.

## Option A: External Scheduler (Recommended)

Use any external scheduler (GitHub Actions, Cloud Scheduler, cron worker) to invoke the edge function every minute.

Example request body:

```json
{
  "batchSize": 50,
  "maxAttempts": 5,
  "lockTimeoutSeconds": 300,
  "workerID": "apns-cron-main"
}
```

Operational notes:
- Keep timeout >= 30s.
- Add jitter (0-10s) if multiple schedulers run in parallel.
- Monitor response fields `claimed`, `sent`, `failed`.

### GitHub Actions Smoke Invocation
- CI workflow: `.github/workflows/p1-validation.yml`
- Manual dispatch can run staging smoke via `run_staging_smoke=true`.
- Manual dispatch can run staging DB migration checks via `run_staging_db_checks=true`.
- Manual dispatch can run one-shot closeout via `run_staging_closeout=true`.
- Required repository secret/variable:
  - `SUPABASE_ACCESS_TOKEN`
  - `STAGING_PROJECT_REF` (Actions variable)
  - `APNS_WORKER_SMOKE_URL`
  - `APNS_WORKER_SMOKE_BEARER`
- Script used by workflow: `backend/live_ops/apns_worker_smoke.sh`
- DB check script used by workflow: `backend/live_ops/run_push_worker_staging_checks.sh`
- Combined closeout script: `backend/live_ops/p1_closeout_staging.sh`

## Option B: Database Cron Trigger

If your Supabase project supports `pg_cron` and `pg_net`, you can schedule HTTP invocation from Postgres.

```sql
select cron.schedule(
  'apns-push-worker-every-minute',
  '* * * * *',
  $$
  select
    net.http_post(
      url := 'https://<project-ref>.functions.supabase.co/apns-push-worker',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer <function-jwt-or-service-role-key>'
      ),
      body := '{"batchSize":50,"maxAttempts":5,"lockTimeoutSeconds":300,"workerID":"apns-cron-db"}'::jsonb
    );
  $$
);
```

## Recommended Starting Thresholds
- Queue backlog SLO: most queued jobs processed within 2 minutes.
- Alert if oldest queued job age > 5 minutes.
- Alert if terminal `failed` jobs exceed 2% in 15-minute windows.

## Key Rotation Checklist
1. Generate new APNs key in Apple Developer portal.
2. Update `APNS_KEY_ID` and `APNS_PRIVATE_KEY_P8` secret values.
3. Redeploy edge function (`supabase functions deploy apns-push-worker`).
4. Verify successful sends and no spike in `403`/`ExpiredProviderToken` failures.
5. Revoke old APNs key after validation window.
