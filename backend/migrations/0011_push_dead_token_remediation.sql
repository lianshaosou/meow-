create or replace function public.deactivate_push_token_for_job(
  input_job_id uuid,
  input_reason text default 'apns_unregistered'
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_token_id uuid;
  v_reason text := coalesce(nullif(btrim(input_reason), ''), 'apns_unregistered');
  v_token_updated integer := 0;
begin
  if auth.role() <> 'service_role' then
    raise exception 'forbidden';
  end if;

  if input_job_id is null then
    raise exception 'invalid_job_id';
  end if;

  select token_id
  into v_token_id
  from push_delivery_jobs
  where id = input_job_id
  limit 1;

  if v_token_id is null then
    return false;
  end if;

  update push_device_tokens
  set
    is_active = false,
    last_registered_at = now()
  where id = v_token_id
    and is_active = true;

  get diagnostics v_token_updated = row_count;

  update push_delivery_jobs
  set
    status = 'failed',
    processed_at = now(),
    next_attempt_at = now(),
    last_error = 'token_deactivated:' || v_reason,
    locked_at = null,
    locked_by = null,
    provider_response = case
      when provider_response is null then jsonb_build_object('reason', v_reason)
      else provider_response || jsonb_build_object('reason', v_reason)
    end
  where token_id = v_token_id
    and status in ('queued', 'processing');

  return v_token_updated > 0;
end;
$$;

revoke all on function public.deactivate_push_token_for_job(uuid, text) from public;
grant execute on function public.deactivate_push_token_for_job(uuid, text) to service_role;
