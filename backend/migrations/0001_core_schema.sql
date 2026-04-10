create extension if not exists pgcrypto;

create type cat_status as enum ('stray', 'pet', 'shelter');
create type ownership_state as enum ('unowned', 'owned', 'deceased');
create type severity_level as enum ('low', 'medium', 'high', 'critical');
create type transaction_kind as enum ('token', 'cash', 'service', 'reward');

create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  nickname text not null check (char_length(nickname) between 2 and 30),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists homes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  label text not null,
  center_lat double precision not null,
  center_lng double precision not null,
  radius_meters integer not null default 80 check (radius_meters between 20 and 500),
  geohash_prefix text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists homes_user_id_idx on homes(user_id);
create index if not exists homes_geohash_prefix_idx on homes(geohash_prefix);

create table if not exists home_change_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  source text not null,
  quantity integer not null default 0 check (quantity >= 0),
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists home_change_tokens_user_id_idx on home_change_tokens(user_id);

create table if not exists regions (
  id uuid primary key default gen_random_uuid(),
  geohash text not null unique,
  geohash_precision integer not null,
  center_lat double precision,
  center_lng double precision,
  density_tier text not null default 'unknown',
  support_level numeric(6,2) not null default 0,
  risk_level numeric(6,2) not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists regions_density_tier_idx on regions(density_tier);

create table if not exists region_activation_state (
  id uuid primary key default gen_random_uuid(),
  region_id uuid not null references regions(id) on delete cascade,
  activated_by_user_id uuid not null references profiles(id) on delete restrict,
  activated_at timestamptz not null default now(),
  last_simulated_at timestamptz not null default now(),
  is_dormant boolean not null default false
);
create unique index if not exists region_activation_state_region_id_key on region_activation_state(region_id);

create table if not exists cats (
  id uuid primary key default gen_random_uuid(),
  internal_name text not null,
  display_name text,
  status cat_status not null default 'stray',
  ownership_state ownership_state not null default 'unowned',
  owner_user_id uuid references profiles(id) on delete set null,
  origin_region_id uuid references regions(id) on delete set null,
  current_region_id uuid references regions(id) on delete set null,
  is_alive boolean not null default true,
  is_castrated boolean not null default false,
  is_microchipped boolean not null default false,
  gender text not null check (gender in ('female', 'male', 'unknown')),
  born_at timestamptz,
  spawned_at timestamptz not null default now(),
  died_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists cats_owner_user_id_idx on cats(owner_user_id);
create index if not exists cats_origin_region_id_idx on cats(origin_region_id);
create index if not exists cats_current_region_id_idx on cats(current_region_id);
create index if not exists cats_status_idx on cats(status);
create index if not exists cats_is_alive_idx on cats(is_alive);

create table if not exists cat_lineage (
  cat_id uuid primary key references cats(id) on delete cascade,
  mother_cat_id uuid references cats(id) on delete set null,
  father_cat_id uuid references cats(id) on delete set null,
  litter_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists cat_lineage_mother_cat_id_idx on cat_lineage(mother_cat_id);
create index if not exists cat_lineage_father_cat_id_idx on cat_lineage(father_cat_id);

create table if not exists cat_traits (
  cat_id uuid primary key references cats(id) on delete cascade,
  breed text not null default 'unknown',
  friendliness numeric(5,2) not null check (friendliness between 0 and 1),
  aggression numeric(5,2) not null check (aggression between 0 and 1),
  intelligence numeric(5,2) not null check (intelligence between 0 and 1),
  playfulness numeric(5,2) not null check (playfulness between 0 and 1),
  fearfulness numeric(5,2) not null check (fearfulness between 0 and 1),
  stress_tolerance numeric(5,2) not null check (stress_tolerance between 0 and 1),
  disease_susceptibility numeric(5,2) not null check (disease_susceptibility between 0 and 1),
  survival_resilience numeric(5,2) not null check (survival_resilience between 0 and 1),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists cat_appearance (
  cat_id uuid primary key references cats(id) on delete cascade,
  fur_base_color text not null,
  secondary_pattern text not null,
  coat_length text not null,
  eye_color text not null,
  ear_shape text not null,
  tail_shape text not null,
  body_size text not null,
  face_structure text not null,
  scars text[] not null default '{}',
  ear_tip_marker text,
  generated_seed bigint not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists cat_behavior_profiles (
  cat_id uuid primary key references cats(id) on delete cascade,
  trust_level numeric(5,2) not null default 0 check (trust_level between 0 and 1),
  roam_radius_cells integer not null default 1 check (roam_radius_cells between 0 and 20),
  territorial_anchor_region_id uuid references regions(id) on delete set null,
  known_by_user_count integer not null default 0,
  feeding_dependency numeric(5,2) not null default 0 check (feeding_dependency between 0 and 1),
  last_behavior_tick_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists cat_medical_true_state (
  cat_id uuid primary key references cats(id) on delete cascade,
  body_condition numeric(5,2) not null default 1 check (body_condition between 0 and 1),
  hydration numeric(5,2) not null default 1 check (hydration between 0 and 1),
  pain_level numeric(5,2) not null default 0 check (pain_level between 0 and 1),
  stress_level numeric(5,2) not null default 0 check (stress_level between 0 and 1),
  active_conditions jsonb not null default '[]'::jsonb,
  vaccination_state jsonb not null default '{}'::jsonb,
  last_simulated_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists cat_medical_known_state (
  id uuid primary key default gen_random_uuid(),
  cat_id uuid not null references cats(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  known_conditions jsonb not null default '[]'::jsonb,
  suspected_conditions jsonb not null default '[]'::jsonb,
  symptom_notes jsonb not null default '[]'::jsonb,
  diagnosis_confidence numeric(5,2) not null default 0 check (diagnosis_confidence between 0 and 1),
  last_observed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (cat_id, user_id)
);
create index if not exists cat_medical_known_state_user_id_idx on cat_medical_known_state(user_id);

create table if not exists encounter_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  cat_id uuid not null references cats(id) on delete cascade,
  region_id uuid not null references regions(id) on delete cascade,
  encounter_type text not null,
  trust_delta numeric(6,3) not null default 0,
  happened_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb
);
create index if not exists encounter_events_user_id_idx on encounter_events(user_id);
create index if not exists encounter_events_cat_id_idx on encounter_events(cat_id);

create table if not exists adoption_records (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  cat_id uuid not null references cats(id) on delete cascade,
  adopted_at timestamptz not null default now(),
  source_encounter_id uuid references encounter_events(id) on delete set null,
  metadata jsonb not null default '{}'::jsonb,
  unique (cat_id)
);

create table if not exists ownership_history (
  id uuid primary key default gen_random_uuid(),
  cat_id uuid not null references cats(id) on delete cascade,
  owner_user_id uuid references profiles(id) on delete set null,
  event_type text not null,
  changed_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb
);
create index if not exists ownership_history_cat_id_idx on ownership_history(cat_id);

create table if not exists care_actions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  cat_id uuid not null references cats(id) on delete cascade,
  action_type text not null,
  quality_score numeric(5,2) check (quality_score between 0 and 1),
  happened_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb
);
create index if not exists care_actions_user_id_idx on care_actions(user_id);
create index if not exists care_actions_cat_id_idx on care_actions(cat_id);

create table if not exists absence_plans (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  plan_type text not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  reliability_score numeric(5,2) not null check (reliability_score between 0 and 1),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists absence_plans_user_id_idx on absence_plans(user_id);

create table if not exists incident_events (
  id uuid primary key default gen_random_uuid(),
  cat_id uuid references cats(id) on delete set null,
  user_id uuid references profiles(id) on delete set null,
  region_id uuid references regions(id) on delete set null,
  category text not null,
  severity severity_level not null,
  triggered_at timestamptz not null default now(),
  resolved_at timestamptz,
  metadata jsonb not null default '{}'::jsonb
);
create index if not exists incident_events_user_id_idx on incident_events(user_id);
create index if not exists incident_events_cat_id_idx on incident_events(cat_id);

create table if not exists notification_preferences (
  user_id uuid primary key references profiles(id) on delete cascade,
  allow_encounter_notifications boolean not null default true,
  allow_night_emergencies boolean not null default true,
  night_start_hour integer not null default 23 check (night_start_hour between 0 and 23),
  night_end_hour integer not null default 7 check (night_end_hour between 0 and 23),
  minimum_severity_for_night severity_level not null default 'high',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists notification_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  category text not null,
  severity severity_level not null default 'low',
  title text not null,
  body text not null,
  payload jsonb not null default '{}'::jsonb,
  scheduled_for timestamptz not null,
  delivered_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists notification_events_user_id_idx on notification_events(user_id);

create table if not exists death_records (
  id uuid primary key default gen_random_uuid(),
  cat_id uuid not null unique references cats(id) on delete cascade,
  user_id uuid references profiles(id) on delete set null,
  cause_category text not null,
  cause_detail text,
  occurred_at timestamptz not null,
  region_id uuid references regions(id) on delete set null,
  archived_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists memorials (
  id uuid primary key default gen_random_uuid(),
  cat_id uuid not null unique references cats(id) on delete cascade,
  user_id uuid references profiles(id) on delete set null,
  title text,
  note text,
  portrait_url text,
  visibility text not null default 'private' check (visibility in ('private', 'friends', 'public')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists stations (
  id uuid primary key default gen_random_uuid(),
  region_id uuid not null references regions(id) on delete cascade,
  name text not null,
  support_score numeric(5,2) not null default 0 check (support_score between 0 and 1),
  funding_balance numeric(12,2) not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists stations_region_id_idx on stations(region_id);

create table if not exists station_funding (
  id uuid primary key default gen_random_uuid(),
  station_id uuid not null references stations(id) on delete cascade,
  user_id uuid references profiles(id) on delete set null,
  amount numeric(12,2) not null,
  currency text not null default 'USD',
  source text not null,
  created_at timestamptz not null default now()
);
create index if not exists station_funding_station_id_idx on station_funding(station_id);

create table if not exists station_maintenance (
  id uuid primary key default gen_random_uuid(),
  station_id uuid not null references stations(id) on delete cascade,
  maintenance_type text not null,
  cost_amount numeric(12,2) not null default 0,
  performed_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb
);
create index if not exists station_maintenance_station_id_idx on station_maintenance(station_id);

create table if not exists economy_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  kind transaction_kind not null,
  category text not null,
  amount numeric(12,2) not null,
  currency text not null default 'USD',
  related_entity text,
  related_entity_id uuid,
  happened_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb
);
create index if not exists economy_transactions_user_id_idx on economy_transactions(user_id);

create table if not exists inventory_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  item_key text not null,
  quantity integer not null default 0 check (quantity >= 0),
  metadata jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  unique (user_id, item_key)
);

create table if not exists service_records (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  cat_id uuid references cats(id) on delete set null,
  service_type text not null,
  service_cost numeric(12,2) not null default 0,
  service_currency text not null default 'USD',
  happened_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb
);
create index if not exists service_records_user_id_idx on service_records(user_id);

create table if not exists simulation_events (
  id uuid primary key default gen_random_uuid(),
  entity_type text not null,
  entity_id uuid not null,
  event_type text not null,
  event_at timestamptz not null default now(),
  simulation_elapsed_seconds integer not null default 0,
  metadata jsonb not null default '{}'::jsonb
);
create index if not exists simulation_events_entity_idx on simulation_events(entity_type, entity_id);

create table if not exists time_state_snapshots (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references profiles(id) on delete cascade,
  entity_type text not null,
  entity_id uuid,
  real_world_timestamp timestamptz not null,
  simulation_timestamp timestamptz not null,
  care_cycle_timestamp timestamptz not null,
  created_at timestamptz not null default now()
);
create index if not exists time_state_snapshots_user_id_idx on time_state_snapshots(user_id);

create table if not exists balance_config_sets (
  id uuid primary key default gen_random_uuid(),
  key text not null unique,
  description text,
  scope text not null default 'global',
  region_code text,
  is_active boolean not null default false,
  created_at timestamptz not null default now(),
  activated_at timestamptz
);

create table if not exists balance_configs (
  id uuid primary key default gen_random_uuid(),
  config_set_id uuid not null references balance_config_sets(id) on delete cascade,
  category text not null,
  config_key text not null,
  config_value jsonb not null,
  created_at timestamptz not null default now(),
  unique (config_set_id, category, config_key)
);
