-- Consolidated operations alert checks
-- Returns a single-row boolean payload suitable for automation.

with lifecycle_recent as (
  select status
  from region_lifecycle_worker_runs
  where created_at >= now() - interval '24 hours'
), lifecycle_calc as (
  select
    count(*) filter (where status = 'failed')::numeric as failed,
    count(*)::numeric as total
  from lifecycle_recent
)
select
  not exists (
    select 1
    from region_lifecycle_worker_runs
    where status = 'success'
      and created_at >= now() - interval '2 hours'
  ) as alert_region_worker_no_success_2h,
  (
    case
      when lifecycle_calc.total = 0 then false
      else (lifecycle_calc.failed / lifecycle_calc.total) > 0.10
    end
  ) as alert_region_worker_failure_rate_over_10pct,
  not exists (
    select 1
    from app_telemetry_events
    where event_name = 'timeline_user_advanced'
      and created_at >= now() - interval '6 hours'
  ) as alert_no_timeline_user_advanced_6h,
  not exists (
    select 1
    from app_telemetry_events
    where event_name = 'encounter_success'
      and created_at >= now() - interval '12 hours'
  ) as alert_no_encounter_success_12h
from lifecycle_calc;
