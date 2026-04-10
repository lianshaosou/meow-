create table if not exists push_device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  token text not null,
  platform text not null check (platform in ('ios')),
  environment text not null check (environment in ('sandbox', 'production')),
  is_active boolean not null default true,
  last_registered_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (user_id, token)
);

create index if not exists push_device_tokens_user_id_idx on push_device_tokens(user_id);

create table if not exists push_delivery_jobs (
  id uuid primary key default gen_random_uuid(),
  notification_id uuid not null references notification_events(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  token_id uuid not null references push_device_tokens(id) on delete cascade,
  channel text not null default 'apns',
  status text not null default 'queued' check (status in ('queued', 'processing', 'sent', 'failed')),
  attempts integer not null default 0,
  payload jsonb not null default '{}'::jsonb,
  last_error text,
  created_at timestamptz not null default now(),
  processed_at timestamptz
);

create index if not exists push_delivery_jobs_user_id_idx on push_delivery_jobs(user_id);
create index if not exists push_delivery_jobs_status_idx on push_delivery_jobs(status, created_at);

alter table push_device_tokens enable row level security;
alter table push_delivery_jobs enable row level security;

create policy "push_device_tokens_owner_all"
on push_device_tokens
for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "push_delivery_jobs_owner_read"
on push_delivery_jobs
for select
using (auth.uid() = user_id);

create or replace function public.register_push_device_token(
  input_token text,
  input_platform text default 'ios',
  input_environment text default 'sandbox'
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_token_id uuid;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'auth_required';
  end if;

  if input_token is null or btrim(input_token) = '' then
    raise exception 'invalid_token';
  end if;

  insert into push_device_tokens (user_id, token, platform, environment, is_active, last_registered_at)
  values (v_user_id, btrim(input_token), coalesce(input_platform, 'ios'), coalesce(input_environment, 'sandbox'), true, now())
  on conflict (user_id, token)
  do update
    set is_active = true,
        platform = excluded.platform,
        environment = excluded.environment,
        last_registered_at = now()
  returning id into v_token_id;

  return v_token_id;
end;
$$;

create or replace function public.enqueue_notification_push(input_notification_id uuid)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_inserted integer := 0;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'auth_required';
  end if;

  if input_notification_id is null then
    raise exception 'invalid_notification_id';
  end if;

  with inserted as (
    insert into push_delivery_jobs (
      notification_id,
      user_id,
      token_id,
      channel,
      status,
      payload
    )
    select
      n.id,
      n.user_id,
      t.id,
      'apns',
      'queued',
      jsonb_build_object(
        'title', n.title,
        'body', n.body,
        'category', n.category,
        'severity', n.severity,
        'notification_id', n.id,
        'user_id', n.user_id,
        'token_id', t.id
      )
    from notification_events n
    join push_device_tokens t on t.user_id = n.user_id and t.is_active = true
    where n.id = input_notification_id
      and n.user_id = v_user_id
    returning id
  )
  select count(*) into v_inserted from inserted;

  return v_inserted;
end;
$$;

revoke all on function public.register_push_device_token(text, text, text) from public;
revoke all on function public.enqueue_notification_push(uuid) from public;

grant execute on function public.register_push_device_token(text, text, text) to authenticated;
grant execute on function public.enqueue_notification_push(uuid) to authenticated;
