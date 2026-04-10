-- Region lifecycle worker observability queries

-- 1) Recent run outcomes (last 24h)
select
  date_trunc('hour', created_at) as hour,
  count(*) as total_runs,
  count(*) filter (where status = 'success') as success_runs,
  count(*) filter (where status = 'failed') as failed_runs,
  sum(dormant_marked) as dormant_marked_total,
  sum(archived_marked) as archived_marked_total
from region_lifecycle_worker_runs
where created_at >= now() - interval '24 hours'
group by 1
order by hour desc;

-- 2) Latest run health snapshot
select
  id,
  worker_id,
  status,
  dormant_marked,
  archived_marked,
  failure_stage,
  error_message,
  started_at,
  finished_at,
  created_at
from region_lifecycle_worker_runs
order by created_at desc
limit 1;

-- 3) Failure reasons (last 7 days)
select
  coalesce(failure_stage, 'unknown') as failure_stage,
  count(*) as failures
from region_lifecycle_worker_runs
where status = 'failed'
  and created_at >= now() - interval '7 days'
group by 1
order by failures desc;

-- 4) Suggested alert checks
-- A) no successful run in past 2 hours
select not exists (
  select 1
  from region_lifecycle_worker_runs
  where status = 'success'
    and created_at >= now() - interval '2 hours'
) as alert_no_successful_run_2h;

-- B) failure rate > 10% in past 24h
with recent as (
  select status
  from region_lifecycle_worker_runs
  where created_at >= now() - interval '24 hours'
), calc as (
  select
    count(*) filter (where status = 'failed')::numeric as failed,
    count(*)::numeric as total
  from recent
)
select
  case
    when total = 0 then false
    else (failed / total) > 0.10
  end as alert_failure_rate_over_10pct
from calc;
