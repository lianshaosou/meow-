create or replace function public.recover_stale_push_delivery_jobs(
  input_lock_timeout_seconds integer default 300,
  input_max_attempts integer default 5
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_lock_timeout_seconds integer := greatest(30, least(coalesce(input_lock_timeout_seconds, 300), 3600));
  v_max_attempts integer := greatest(1, least(coalesce(input_max_attempts, 5), 20));
  v_recovered integer := 0;
begin
  if auth.role() <> 'service_role' then
    raise exception 'forbidden';
  end if;

  with recovered as (
    update push_delivery_jobs
    set
      status = case when attempts >= v_max_attempts then 'failed' else 'queued' end,
      next_attempt_at = case
        when attempts >= v_max_attempts then next_attempt_at
        else now()
      end,
      last_error = coalesce(last_error, 'stale_lock_recovered'),
      locked_at = null,
      locked_by = null,
      processed_at = case when attempts >= v_max_attempts then now() else null end
    where status = 'processing'
      and coalesce(locked_at, created_at) <= now() - make_interval(secs => v_lock_timeout_seconds)
    returning id
  )
  select count(*) into v_recovered from recovered;

  return v_recovered;
end;
$$;

revoke all on function public.recover_stale_push_delivery_jobs(integer, integer) from public;
grant execute on function public.recover_stale_push_delivery_jobs(integer, integer) to service_role;
