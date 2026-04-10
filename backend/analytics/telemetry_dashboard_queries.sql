-- Meow telemetry dashboard queries
-- Run against Supabase Postgres (SQL Editor or psql).

-- 1) Encounter funnel by day (UTC)
with encounter_daily as (
  select
    date_trunc('day', created_at) as day,
    count(*) filter (where event_name = 'encounter_success') as encounter_success,
    count(*) filter (where event_name = 'encounter_roll_empty') as encounter_roll_empty,
    count(*) filter (where event_name = 'encounter_cooldown_active') as encounter_cooldown_active,
    count(*) filter (where event_name = 'encounter_eligibility_blocked') as encounter_eligibility_blocked,
    count(*) filter (where event_name = 'explore_live_location_pending') as explore_live_location_pending,
    count(*) filter (where event_name = 'encounter_check_error') as encounter_check_error
  from app_telemetry_events
  where event_name in (
    'encounter_success',
    'encounter_roll_empty',
    'encounter_cooldown_active',
    'encounter_eligibility_blocked',
    'explore_live_location_pending',
    'encounter_check_error'
  )
  group by 1
)
select
  day,
  encounter_success,
  encounter_roll_empty,
  encounter_cooldown_active,
  encounter_eligibility_blocked,
  explore_live_location_pending,
  encounter_check_error,
  (encounter_success + encounter_roll_empty) as attempted_rolls,
  case
    when (encounter_success + encounter_roll_empty) = 0 then 0
    else round((encounter_success::numeric / (encounter_success + encounter_roll_empty)) * 100, 2)
  end as roll_success_rate_pct
from encounter_daily
order by day desc;

-- 2) Encounter eligibility block reasons by day
select
  date_trunc('day', created_at) as day,
  coalesce(properties->>'reason', 'unknown') as block_reason,
  count(*) as events
from app_telemetry_events
where event_name = 'encounter_eligibility_blocked'
group by 1, 2
order by day desc, events desc;

-- 3) Account/provider link funnel by day
with link_daily as (
  select
    date_trunc('day', created_at) as day,
    count(*) filter (where event_name = 'account_link_email_success') as account_link_email_success,
    count(*) filter (where event_name = 'account_link_email_failed') as account_link_email_failed,
    count(*) filter (where event_name = 'provider_unlink_attempt') as provider_unlink_attempt,
    count(*) filter (where event_name = 'provider_unlink_reauth_prompted') as provider_unlink_reauth_prompted,
    count(*) filter (where event_name = 'provider_reauth_success') as provider_reauth_success,
    count(*) filter (where event_name = 'provider_reauth_failed') as provider_reauth_failed,
    count(*) filter (where event_name = 'provider_unlink_success') as provider_unlink_success,
    count(*) filter (where event_name = 'provider_unlink_failed') as provider_unlink_failed
  from app_telemetry_events
  where event_name in (
    'account_link_email_success',
    'account_link_email_failed',
    'provider_unlink_attempt',
    'provider_unlink_reauth_prompted',
    'provider_reauth_success',
    'provider_reauth_failed',
    'provider_unlink_success',
    'provider_unlink_failed'
  )
  group by 1
)
select
  day,
  account_link_email_success,
  account_link_email_failed,
  provider_unlink_attempt,
  provider_unlink_reauth_prompted,
  provider_reauth_success,
  provider_reauth_failed,
  provider_unlink_success,
  provider_unlink_failed,
  case
    when provider_unlink_attempt = 0 then 0
    else round((provider_unlink_success::numeric / provider_unlink_attempt) * 100, 2)
  end as provider_unlink_completion_rate_pct
from link_daily
order by day desc;

-- 4) Provider unlink drop-off reasons (last 30 days)
select
  coalesce(properties->>'reason', 'unknown') as reason,
  count(*) as failed_events
from app_telemetry_events
where event_name = 'provider_unlink_failed'
  and created_at >= now() - interval '30 days'
group by 1
order by failed_events desc;

-- 5) Provider unlink source split (direct vs retry)
select
  coalesce(properties->>'source', 'direct') as source,
  count(*) filter (where event_name = 'provider_unlink_success') as success_count,
  count(*) filter (where event_name = 'provider_unlink_failed') as failed_count,
  count(*) filter (where event_name = 'provider_unlink_reauth_prompted') as reauth_prompt_count
from app_telemetry_events
where event_name in ('provider_unlink_success', 'provider_unlink_failed', 'provider_unlink_reauth_prompted')
group by 1
order by source;

-- 6) Encounter ecology context split (last 30 days)
select
  coalesce(properties->>'cat_source', 'unknown') as cat_source,
  count(*) filter (where event_name = 'encounter_success') as success_events,
  count(*) filter (where event_name = 'encounter_roll_empty') as empty_roll_events,
  count(*) filter (where event_name = 'encounter_success' and coalesce(properties->>'adjacent_roam_used', 'false') = 'true') as adjacent_roam_success_events,
  round(avg(nullif(properties->>'familiar_encounter_count', '')::numeric) filter (where event_name = 'encounter_success'), 2) as avg_familiar_count
from app_telemetry_events
where event_name in ('encounter_success', 'encounter_roll_empty')
  and created_at >= now() - interval '30 days'
group by 1
order by success_events desc, cat_source;

-- 7) Region reactivation context on successful encounters (last 30 days)
select
  coalesce(properties->>'was_reactivated', 'unknown') as was_reactivated,
  count(*) as success_events
from app_telemetry_events
where event_name = 'encounter_success'
  and created_at >= now() - interval '30 days'
group by 1
order by success_events desc;

-- 8) Timeline consumer signals by day
select
  date_trunc('day', created_at) as day,
  count(*) filter (where event_name = 'timeline_user_advanced') as timeline_user_advanced,
  count(*) filter (where event_name = 'timeline_home_care_due') as timeline_home_care_due,
  count(*) filter (where event_name = 'timeline_region_dormancy_candidate') as timeline_region_dormancy_candidate
from app_telemetry_events
where event_name in (
  'timeline_user_advanced',
  'timeline_home_care_due',
  'timeline_region_dormancy_candidate'
)
group by 1
order by day desc;

-- 9) Timeline care due elapsed-hour distribution (last 30 days)
select
  coalesce(properties->>'elapsed_hours', 'unknown') as elapsed_hours,
  count(*) as events
from app_telemetry_events
where event_name = 'timeline_home_care_due'
  and created_at >= now() - interval '30 days'
group by 1
order by events desc;

-- 10) Timeline signal alert checks
-- A) no timeline_user_advanced events in last 6 hours
select not exists (
  select 1
  from app_telemetry_events
  where event_name = 'timeline_user_advanced'
    and created_at >= now() - interval '6 hours'
) as alert_no_timeline_user_advanced_6h;

-- B) no timeline_region_dormancy_candidate events in last 48 hours
select not exists (
  select 1
  from app_telemetry_events
  where event_name = 'timeline_region_dormancy_candidate'
    and created_at >= now() - interval '48 hours'
) as alert_no_dormancy_candidates_48h;
