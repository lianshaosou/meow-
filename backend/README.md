# Backend Foundation (Supabase/Postgres)

This folder contains the initial database foundation for the Meow simulation backend.

## Included
- `migrations/0001_core_schema.sql`: core entities and indexes.
- `migrations/0002_rls_policies.sql`: initial row-level security and ownership policies.
- `migrations/0003_region_activation_rpc.sql`: region activation + encounter roll RPC.
- `migrations/0004_app_telemetry.sql`: app telemetry event table and RLS.
- `migrations/0005_region_enrichment_and_rpc_upgrade.sql`: region-country overrides and RPC upgrade.
- `migrations/0006_notification_delivery_worker.sql`: delivery worker state columns and notification RPCs.
- `migrations/0007_push_bridge.sql`: APNs token registration and push enqueue bridge.
- `migrations/0008_country_override_live_ops_tools.sql`: service-role RPCs for dynamic country override management.
- `migrations/0009_push_delivery_provider_worker.sql`: service-role RPCs for claiming and marking APNs push jobs.
- `migrations/0010_push_delivery_stale_lock_recovery.sql`: service-role RPC to recover stale `processing` jobs.
- `migrations/0011_push_dead_token_remediation.sql`: service-role RPC to deactivate invalid APNs tokens and close affected jobs.
- `migrations/0012_fix_push_claim_rpc_ambiguity.sql`: fixes claim RPC ambiguity for stable worker execution.
- `migrations/0013_region_dormancy_lifecycle.sql`: formal region lifecycle states and dormancy/archive transitions.
- `migrations/0014_encounter_ecology_familiarity_and_roaming.sql`: familiarity-biased re-encounter weighting and adjacency roaming encounter selection.
- `migrations/0015_region_lifecycle_worker_runs.sql`: run-log table for lifecycle worker observability and alerting.
- `analytics/telemetry_dashboard_queries.sql`: dashboard-ready SQL queries for encounter and provider-link funnels.
- `analytics/push_worker_observability_queries.sql`: queue/failure/APNs reason queries for push worker SLO monitoring.
- `analytics/region_dormancy_queries.sql`: region lifecycle/dormancy observability queries.
- `analytics/region_lifecycle_worker_observability_queries.sql`: lifecycle worker run health/failure-rate alert queries.
- `analytics/ops_alert_checks.sql`: consolidated boolean alert checks for lifecycle worker and telemetry health.
- `live_ops/COUNTRY_OVERRIDE_RUNBOOK.md`: runbook and examples for live override updates.
- `live_ops/APNS_PUSH_WORKER.md`: runbook for provider worker claim/send/mark loop.
- `live_ops/APNS_PUSH_WORKER_SCHEDULING.md`: production scheduling and token-rotation checklist.
- `live_ops/REGION_DORMANCY_RUNBOOK.md`: lifecycle transition and retention operations for region state.
- `live_ops/REGION_LIFECYCLE_WORKER_SCHEDULING.md`: scheduling guidance for region lifecycle worker sweeps.
- `live_ops/region_lifecycle_worker_smoke.sh`: invocation/smoke script for `region-lifecycle-worker`.
- `live_ops/ANALYTICS_ALERT_RUNBOOK.md`: operational response guide for dashboard alert checks.
- `live_ops/run_ops_alert_checks.sh`: scheduled checker for `ops_alert_checks.sql` with optional webhook notification.
- `live_ops/run_push_worker_staging_checks.sh`: staging migration/apply verification helper (migrations `0009`-`0012`).
- `live_ops/push_worker_staging_verify.sql`: verifies push worker RPC registrations after staging apply.
- `live_ops/p1_closeout_staging.sh`: one-shot staging closeout runner (DB checks + smoke invocation).
- `live_ops/p1_closeout_dispatch.md`: how to trigger and verify P1 closeout workflow run.
- `functions/apns-push-worker/*`: deployable edge function scaffold for APNs worker runtime.
- `seeds/0001_global_balance_seed.sql`: global default tuning values.

## Apply Order
1. `0001_core_schema.sql`
2. `0002_rls_policies.sql`
3. `0003_region_activation_rpc.sql`
4. `0004_app_telemetry.sql`
5. `0005_region_enrichment_and_rpc_upgrade.sql`
6. `0006_notification_delivery_worker.sql`
7. `0007_push_bridge.sql`
8. `0008_country_override_live_ops_tools.sql`
9. `0009_push_delivery_provider_worker.sql`
10. `0010_push_delivery_stale_lock_recovery.sql`
11. `0011_push_dead_token_remediation.sql`
12. `0012_fix_push_claim_rpc_ambiguity.sql`
13. `0013_region_dormancy_lifecycle.sql`
14. `0014_encounter_ecology_familiarity_and_roaming.sql`
15. `0015_region_lifecycle_worker_runs.sql`
16. `0001_global_balance_seed.sql`

## Notes
- This schema is intentionally simulation-first and data-driven.
- Balancing values live in `balance_config_sets` + `balance_configs` and are meant to be tuned over time.
- `cat_medical_true_state` is service-role readable only by default to preserve hidden-state design.

## Live Ops Country Overrides
- Use service-role RPCs from `0008_country_override_live_ops_tools.sql` for dynamic country balancing updates.
- See `live_ops/COUNTRY_OVERRIDE_RUNBOOK.md` for usage examples and guardrails.

## Region Dormancy Lifecycle
- Use service-role RPCs from `0013_region_dormancy_lifecycle.sql` for stale-to-dormant and dormant-to-archived transitions.
- See `live_ops/REGION_DORMANCY_RUNBOOK.md` for scheduling and retention operations.
- Use `supabase/functions/region-lifecycle-worker/index.ts` as scheduled runtime path for hourly sweeps.
- See `live_ops/REGION_LIFECYCLE_WORKER_SCHEDULING.md` for scheduler patterns.

## Encounter Ecology Persistence
- `activate_region_and_roll_encounter` now favors familiar re-encounters and can select adjacent roaming strays.
- Encounter metadata persists ecology context (`cat_source`, familiarity count, adjacent roam usage) in `encounter_events.metadata`.

## APNs Provider Worker
- Use service-role RPCs from `0009_push_delivery_provider_worker.sql` to claim and acknowledge push jobs.
- Use stale-lock recovery RPC from `0010_push_delivery_stale_lock_recovery.sql` to requeue crashed-worker locks.
- Use dead-token remediation RPC from `0011_push_dead_token_remediation.sql` to deactivate invalid APNs tokens.
- See `live_ops/APNS_PUSH_WORKER.md` for worker loop and SQL usage examples.
- See `live_ops/APNS_PUSH_WORKER_SCHEDULING.md` for scheduler patterns and rollout thresholds.
- See `functions/apns-push-worker/README.md` for edge-function deployment and invocation examples.

## Telemetry Dashboard Queries
- Use `analytics/telemetry_dashboard_queries.sql` in Supabase SQL Editor to build first dashboards.
- Includes:
  - encounter funnel and success rates
  - eligibility block reason breakdown
  - account-link/provider-unlink funnel metrics
  - provider unlink failure reason and direct-vs-retry split

## Push Worker Observability
- Use `analytics/push_worker_observability_queries.sql` for push queue health and SLO alert checks.

## Region Dormancy Observability
- Use `analytics/region_dormancy_queries.sql` for lifecycle state counts and dormant retention monitoring.

## Region Lifecycle Worker Observability
- `region-lifecycle-worker` writes run summaries to `region_lifecycle_worker_runs`.
- Use `analytics/region_lifecycle_worker_observability_queries.sql` for failure-rate and stale-run alerts.

## Consolidated Ops Alerts
- Use `analytics/ops_alert_checks.sql` for boolean alert tiles and lightweight automation checks.
- Follow `live_ops/ANALYTICS_ALERT_RUNBOOK.md` for response playbooks.
- Use `.github/workflows/ops-alert-checks.yml` to run checks on schedule and notify webhook on active alerts.
- Optional: set Actions variable `CREATE_GITHUB_INCIDENT_ON_ALERT=true` to auto-open incident issues on active alerts.
