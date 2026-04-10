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
    select j.id as job_id
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
    where j.id in (select candidate.job_id from candidate)
    returning j.id, j.notification_id, j.user_id, j.token_id, j.payload, j.attempts, j.next_attempt_at
  )
  select
    claimed.id,
    claimed.notification_id,
    claimed.user_id,
    t.token,
    t.environment,
    claimed.payload,
    claimed.attempts,
    claimed.next_attempt_at
  from claimed
  join push_device_tokens t on t.id = claimed.token_id;
end;
$$;

revoke all on function public.claim_push_delivery_jobs(integer, text, integer) from public;
grant execute on function public.claim_push_delivery_jobs(integer, text, integer) to service_role;
