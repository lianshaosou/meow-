-- APNs push worker observability queries
-- Use in Supabase SQL editor for dashboards and alerting.

-- 1) Queue depth by status
select
  status,
  count(*) as jobs
from push_delivery_jobs
group by status
order by status;

-- 2) Oldest queued/failed retry age (minutes)
select
  round(extract(epoch from (now() - min(created_at))) / 60.0, 2) as oldest_pending_minutes
from push_delivery_jobs
where status in ('queued', 'failed')
  and next_attempt_at <= now();

-- 3) Delivery outcomes by 15-minute window
select
  date_trunc('minute', created_at) - make_interval(mins => mod(extract(minute from created_at)::int, 15)) as bucket_15m,
  count(*) filter (where status = 'sent') as sent,
  count(*) filter (where status = 'failed') as failed_terminal,
  count(*) filter (where status = 'queued') as queued,
  count(*) filter (where status = 'processing') as processing
from push_delivery_jobs
where created_at >= now() - interval '24 hours'
group by 1
order by bucket_15m desc;

-- 4) Terminal failure rate (last 15 minutes)
with recent as (
  select status
  from push_delivery_jobs
  where created_at >= now() - interval '15 minutes'
)
select
  count(*) filter (where status = 'failed') as failed_terminal,
  count(*) filter (where status = 'sent') as sent,
  count(*) as total,
  case
    when count(*) = 0 then 0
    else round((count(*) filter (where status = 'failed'))::numeric * 100 / count(*), 2)
  end as failed_terminal_rate_pct
from recent;

-- 5) APNs error reason breakdown (last 24h)
select
  coalesce(provider_response->>'reason', last_error, 'unknown') as reason,
  count(*) as failures
from push_delivery_jobs
where status = 'failed'
  and created_at >= now() - interval '24 hours'
group by 1
order by failures desc;

-- 6) Stuck processing jobs (possible worker crash)
select
  id,
  user_id,
  attempts,
  locked_at,
  locked_by,
  created_at,
  now() - coalesce(locked_at, created_at) as processing_duration
from push_delivery_jobs
where status = 'processing'
  and coalesce(locked_at, created_at) <= now() - interval '5 minutes'
order by coalesce(locked_at, created_at) asc;

-- 7) Suggested alert checks
-- A) queue lag > 5 minutes
select exists (
  select 1
  from push_delivery_jobs
  where status in ('queued', 'failed')
    and next_attempt_at <= now()
    and created_at <= now() - interval '5 minutes'
) as alert_queue_lag_over_5m;

-- B) terminal failure rate > 2% in last 15 minutes
with recent as (
  select status
  from push_delivery_jobs
  where created_at >= now() - interval '15 minutes'
), calc as (
  select
    count(*) filter (where status = 'failed')::numeric as failed,
    count(*)::numeric as total
  from recent
)
select
  case
    when total = 0 then false
    else (failed / total) > 0.02
  end as alert_failed_rate_over_2pct
from calc;
