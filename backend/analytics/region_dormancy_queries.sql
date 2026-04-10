-- Region dormancy observability queries

-- 1) Current lifecycle counts
select
  state,
  count(*) as regions
from region_activation_state
group by state
order by state;

-- 2) Dormant regions by age bucket
select
  case
    when dormant_at >= now() - interval '1 day' then '0-1d'
    when dormant_at >= now() - interval '7 days' then '1-7d'
    when dormant_at >= now() - interval '30 days' then '7-30d'
    else '30d+'
  end as dormant_age_bucket,
  count(*) as regions
from region_activation_state
where state = 'dormant'
group by 1
order by 1;

-- 3) Dormant regions with retention already elapsed
select
  count(*) as overdue_dormant_regions
from region_activation_state
where state = 'dormant'
  and retention_until is not null
  and retention_until <= now();

-- 4) Regions reactivated in last 24h
select
  count(*) as reactivated_regions_24h
from region_activation_state
where last_reactivated_at is not null
  and last_reactivated_at >= now() - interval '24 hours';
