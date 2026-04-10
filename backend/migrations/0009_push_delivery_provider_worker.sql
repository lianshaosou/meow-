alter table push_delivery_jobs
  add column if not exists next_attempt_at timestamptz not null default now(),
  add column if not exists locked_at timestamptz,
  add column if not exists locked_by text,
  add column if not exists provider_response jsonb not null default '{}'::jsonb;

create index if not exists push_delivery_jobs_retry_idx
  on push_delivery_jobs(status, next_attempt_at, created_at);

create or replace function public.claim_push_delivery_jobs(
  input_batch_size integer default 50,
  input_worker_id text default null,
  input_max_attempts integer default 5
)
returns table (
  id uuid,
  notification_id uuid,
  user_id uuid,
  token text,
  environment text,
  payload jsonb,
  attempts integer,
  next_attempt_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_batch_size integer := greatest(1, least(coalesce(input_batch_size, 50), 500));
  v_worker_id text := nullif(btrim(input_worker_id), '');
  v_max_attempts integer := greatest(1, least(coalesce(input_max_attempts, 5), 20));
begin
  if auth.role() <> 'service_role' then
    raise exception 'forbidden';
  end if;

  return query
  with candidate as (
    select j.id
    from push_delivery_jobs j
    join push_device_tokens t on t.id = j.token_id
    where j.status in ('queued', 'failed')
      and j.next_attempt_at <= now()
      and j.attempts < v_max_attempts
      and t.is_active = true
    order by j.created_at asc
    limit v_batch_size
    for update skip locked
  ), claimed as (
    update push_delivery_jobs j
    set
      status = 'processing',
      attempts = j.attempts + 1,
      locked_at = now(),
      locked_by = coalesce(v_worker_id, 'worker-' || substring(gen_random_uuid()::text from 1 for 8)),
      processed_at = null
    where j.id in (select id from candidate)
    returning j.id, j.notification_id, j.user_id, j.token_id, j.payload, j.attempts, j.next_attempt_at
  )
  select
    c.id,
    c.notification_id,
    c.user_id,
    t.token,
    t.environment,
    c.payload,
    c.attempts,
    c.next_attempt_at
  from claimed c
  join push_device_tokens t on t.id = c.token_id;
end;
$$;

create or replace function public.mark_push_delivery_job_sent(
  input_job_id uuid,
  input_provider_response jsonb default '{}'::jsonb
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_updated integer;
begin
  if auth.role() <> 'service_role' then
    raise exception 'forbidden';
  end if;

  update push_delivery_jobs
  set
    status = 'sent',
    processed_at = now(),
    last_error = null,
    locked_at = null,
    locked_by = null,
    provider_response = coalesce(input_provider_response, '{}'::jsonb)
  where id = input_job_id
    and status = 'processing';

  get diagnostics v_updated = row_count;
  return v_updated > 0;
end;
$$;

create or replace function public.mark_push_delivery_job_failed(
  input_job_id uuid,
  input_error text,
  input_retry_delay_seconds integer default 60,
  input_max_attempts integer default 5,
  input_provider_response jsonb default '{}'::jsonb
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_updated integer;
  v_retry_delay_seconds integer := greatest(1, least(coalesce(input_retry_delay_seconds, 60), 86400));
  v_max_attempts integer := greatest(1, least(coalesce(input_max_attempts, 5), 20));
begin
  if auth.role() <> 'service_role' then
    raise exception 'forbidden';
  end if;

  update push_delivery_jobs
  set
    status = case when attempts >= v_max_attempts then 'failed' else 'queued' end,
    last_error = coalesce(nullif(btrim(input_error), ''), 'push delivery failed'),
    next_attempt_at = case
      when attempts >= v_max_attempts then now()
      else now() + make_interval(secs => v_retry_delay_seconds)
    end,
    processed_at = case when attempts >= v_max_attempts then now() else null end,
    locked_at = null,
    locked_by = null,
    provider_response = coalesce(input_provider_response, '{}'::jsonb)
  where id = input_job_id
    and status = 'processing';

  get diagnostics v_updated = row_count;
  return v_updated > 0;
end;
$$;

revoke all on function public.claim_push_delivery_jobs(integer, text, integer) from public;
revoke all on function public.mark_push_delivery_job_sent(uuid, jsonb) from public;
revoke all on function public.mark_push_delivery_job_failed(uuid, text, integer, integer, jsonb) from public;

grant execute on function public.claim_push_delivery_jobs(integer, text, integer) to service_role;
grant execute on function public.mark_push_delivery_job_sent(uuid, jsonb) to service_role;
grant execute on function public.mark_push_delivery_job_failed(uuid, text, integer, integer, jsonb) to service_role;
