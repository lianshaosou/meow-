create table if not exists region_lifecycle_worker_runs (
  id uuid primary key default gen_random_uuid(),
  worker_id text not null,
  status text not null check (status in ('success', 'failed')),
  dormant_marked integer not null default 0,
  archived_marked integer not null default 0,
  idle_hours integer,
  batch_size integer,
  run_archive_sweep boolean not null default true,
  failure_stage text,
  error_message text,
  details jsonb not null default '{}'::jsonb,
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists region_lifecycle_worker_runs_created_at_idx
  on region_lifecycle_worker_runs(created_at desc);

create index if not exists region_lifecycle_worker_runs_status_idx
  on region_lifecycle_worker_runs(status, created_at desc);

alter table region_lifecycle_worker_runs enable row level security;

drop policy if exists "region_lifecycle_worker_runs_service_read" on region_lifecycle_worker_runs;
create policy "region_lifecycle_worker_runs_service_read"
on region_lifecycle_worker_runs
for select
using (auth.role() = 'service_role');

drop policy if exists "region_lifecycle_worker_runs_service_insert" on region_lifecycle_worker_runs;
create policy "region_lifecycle_worker_runs_service_insert"
on region_lifecycle_worker_runs
for insert
with check (auth.role() = 'service_role');
