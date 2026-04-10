# Analytics Alert Runbook

This runbook defines baseline alert checks for P2 operations.

## Query Packs
- `backend/analytics/telemetry_dashboard_queries.sql`
- `backend/analytics/push_worker_observability_queries.sql`
- `backend/analytics/region_lifecycle_worker_observability_queries.sql`
- `backend/analytics/ops_alert_checks.sql`

## Minimum Alerts
1. Region lifecycle worker has no successful run in 2h.
2. Region lifecycle worker failure rate > 10% in 24h.
3. No `timeline_user_advanced` telemetry in 6h.
4. No `encounter_success` in 12h.

## Response Playbook
- If worker success gap alert fires:
  - check `.github/workflows/region-lifecycle-worker.yml` latest runs
  - manually invoke `region_lifecycle_worker_smoke.sh`
  - inspect latest row in `region_lifecycle_worker_runs`
- If worker failure-rate alert fires:
  - group failures by `failure_stage`
  - verify RPC permissions and migration state
  - reduce `batchSize` and retry
- If timeline/encounter telemetry gaps fire:
  - verify app bootstrap tasks are executing
  - verify telemetry ingestion (`app_telemetry_events`) from latest app sessions

## SQL Editor Quick Start
Run `backend/analytics/ops_alert_checks.sql` and pin each boolean output as a dashboard status tile.

## Automated Check Job
- Workflow: `.github/workflows/ops-alert-checks.yml`
- Schedule: hourly at minute 15
- Script: `backend/live_ops/run_ops_alert_checks.sh`
- Required GitHub secret/variable:
  - `SUPABASE_ACCESS_TOKEN`
  - `STAGING_PROJECT_REF` (Actions variable)
- Optional webhook secret:
  - `OPS_ALERT_WEBHOOK_URL` (posts JSON payload when any alert is true)
- Optional incident issue toggle:
  - Actions variable `CREATE_GITHUB_INCIDENT_ON_ALERT=true`
  - when enabled, workflow opens GitHub issue labeled `incident` and `ops-alert`.
