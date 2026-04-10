# Region Lifecycle Worker Scheduling Guide

This guide schedules `region-lifecycle-worker` for dormancy/archive sweeps.

## Worker Endpoint
- `https://<project-ref>.functions.supabase.co/region-lifecycle-worker`

## Request Body

```json
{
  "idleHours": 72,
  "batchSize": 500,
  "dormancyReason": "idle_timeout",
  "archiveReason": "retention_elapsed",
  "retentionDays": null,
  "runArchiveSweep": true
}
```

## Recommended Schedules
- Dormancy + archive sweep every hour:
  - cron: `0 * * * *`
- High-throughput projects can run every 15 minutes with lower `batchSize`.

## GitHub Actions Schedule Path
- Workflow: `.github/workflows/region-lifecycle-worker.yml`
- Runs hourly via cron and supports manual dispatch.
- Required repository secrets:
  - `REGION_LIFECYCLE_WORKER_URL`
  - `REGION_LIFECYCLE_WORKER_BEARER`
- Worker invocation script:
  - `backend/live_ops/region_lifecycle_worker_smoke.sh`

## Option A: External Scheduler (Recommended)
- Trigger function on schedule (Cloud Scheduler, GitHub Actions, cron service).
- Ensure Authorization header includes a valid function bearer token.

## Option B: Database Cron Trigger

```sql
select cron.schedule(
  'region-lifecycle-worker-hourly',
  '0 * * * *',
  $$
  select
    net.http_post(
      url := 'https://<project-ref>.functions.supabase.co/region-lifecycle-worker',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer <function-jwt-or-service-role-key>'
      ),
      body := '{"idleHours":72,"batchSize":500,"runArchiveSweep":true}'::jsonb
    );
  $$
);
```

## Operational Targets
- Dormant transition lag: stale active regions processed within 2 hours.
- Archive lag: expired dormant regions archived within 24 hours.

## Observability and Alerts
- Worker persists run summaries in `region_lifecycle_worker_runs`.
- Query pack:
  - `backend/analytics/region_lifecycle_worker_observability_queries.sql`
- Suggested alerts:
  - no successful worker run in 2 hours
  - worker failure rate over 10% in 24 hours
