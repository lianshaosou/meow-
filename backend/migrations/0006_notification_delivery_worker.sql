alter table notification_events
  add column if not exists delivery_status text not null default 'scheduled'
    check (delivery_status in ('scheduled', 'processing', 'delivered', 'failed')),
  add column if not exists delivery_attempts integer not null default 0,
  add column if not exists last_delivery_error text,
  add column if not exists processing_started_at timestamptz;

create index if not exists notification_events_delivery_status_idx
  on notification_events(delivery_status, scheduled_for);

create or replace function public.claim_due_notifications(input_batch_size integer default 20)
returns table (
  id uuid,
  user_id uuid,
  category text,
  severity severity_level,
  title text,
  body text,
  payload jsonb,
  scheduled_for timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'auth_required';
  end if;

  return query
  with picked as (
    select n.id
    from notification_events n
    where n.user_id = v_user_id
      and n.delivered_at is null
      and n.delivery_status in ('scheduled', 'failed')
      and n.scheduled_for <= now()
    order by n.scheduled_for asc
    limit greatest(1, least(input_batch_size, 100))
    for update skip locked
  ), updated as (
    update notification_events n
    set delivery_status = 'processing',
        delivery_attempts = n.delivery_attempts + 1,
        processing_started_at = now(),
        last_delivery_error = null
    from picked
    where n.id = picked.id
    returning n.id, n.user_id, n.category, n.severity, n.title, n.body, n.payload, n.scheduled_for
  )
  select * from updated;
end;
$$;

create or replace function public.mark_notification_delivered(input_notification_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'auth_required';
  end if;

  update notification_events
  set delivery_status = 'delivered',
      delivered_at = now(),
      last_delivery_error = null
  where id = input_notification_id
    and user_id = v_user_id;
end;
$$;

create or replace function public.mark_notification_failed(input_notification_id uuid, input_error text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'auth_required';
  end if;

  update notification_events
  set delivery_status = 'failed',
      last_delivery_error = left(coalesce(input_error, 'unknown_error'), 1000)
  where id = input_notification_id
    and user_id = v_user_id;
end;
$$;

revoke all on function public.claim_due_notifications(integer) from public;
revoke all on function public.mark_notification_delivered(uuid) from public;
revoke all on function public.mark_notification_failed(uuid, text) from public;

grant execute on function public.claim_due_notifications(integer) to authenticated;
grant execute on function public.mark_notification_delivered(uuid) to authenticated;
grant execute on function public.mark_notification_failed(uuid, text) to authenticated;
