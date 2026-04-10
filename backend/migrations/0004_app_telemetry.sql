create table if not exists app_telemetry_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  event_name text not null,
  properties jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists app_telemetry_events_user_id_idx on app_telemetry_events(user_id);
create index if not exists app_telemetry_events_event_name_idx on app_telemetry_events(event_name);
create index if not exists app_telemetry_events_created_at_idx on app_telemetry_events(created_at);

alter table app_telemetry_events enable row level security;

create policy "app_telemetry_owner_all"
on app_telemetry_events
for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);
