alter table region_activation_state
  add column if not exists state text not null default 'active',
  add column if not exists dormant_at timestamptz,
  add column if not exists archived_at timestamptz,
  add column if not exists dormancy_reason text,
  add column if not exists retention_until timestamptz,
  add column if not exists activation_count integer not null default 1,
  add column if not exists last_activated_at timestamptz not null default now(),
  add column if not exists last_reactivated_at timestamptz,
  add column if not exists last_dormant_transition_at timestamptz;

alter table region_activation_state
  drop constraint if exists region_activation_state_state_check;

alter table region_activation_state
  add constraint region_activation_state_state_check
  check (state in ('active', 'dormant', 'archived'));

alter table region_activation_state
  drop constraint if exists region_activation_state_activation_count_check;

alter table region_activation_state
  add constraint region_activation_state_activation_count_check
  check (activation_count >= 0);

update region_activation_state
set
  state = case when is_dormant then 'dormant' else 'active' end,
  last_activated_at = coalesce(last_activated_at, activated_at, last_simulated_at, now()),
  activation_count = greatest(1, coalesce(activation_count, 1)),
  dormant_at = case
    when is_dormant and dormant_at is null then activated_at
    else dormant_at
  end
where true;

create index if not exists region_activation_state_state_idx
  on region_activation_state(state, last_simulated_at);

create index if not exists region_activation_state_retention_until_idx
  on region_activation_state(retention_until)
  where state = 'dormant';

create or replace function public.resolve_region_dormancy_retention_days(input_default integer default 30)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_days integer;
begin
  select (bc.config_value #>> '{}')::integer
  into v_days
  from balance_configs bc
  join balance_config_sets bcs on bcs.id = bc.config_set_id
  where bcs.is_active = true
    and bc.category = 'simulation'
    and bc.config_key = 'region_dormancy_retention_days'
  order by case when bcs.scope = 'global' then 0 else 1 end
  limit 1;

  v_days := coalesce(v_days, input_default, 30);
  v_days := greatest(1, least(v_days, 3650));
  return v_days;
end;
$$;

create or replace function public.mark_stale_regions_dormant(
  input_idle_hours integer default 72,
  input_batch_size integer default 500,
  input_reason text default 'idle_timeout',
  input_retention_days integer default null
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_idle_hours integer := greatest(1, least(coalesce(input_idle_hours, 72), 24 * 365));
  v_batch_size integer := greatest(1, least(coalesce(input_batch_size, 500), 2000));
  v_reason text := coalesce(nullif(btrim(input_reason), ''), 'idle_timeout');
  v_retention_days integer := resolve_region_dormancy_retention_days(coalesce(input_retention_days, 30));
  v_updated integer := 0;
begin
  if auth.role() <> 'service_role' then
    raise exception 'forbidden';
  end if;

  with candidates as (
    select ras.id
    from region_activation_state ras
    where ras.state = 'active'
      and ras.last_simulated_at <= now() - make_interval(hours => v_idle_hours)
    order by ras.last_simulated_at asc
    limit v_batch_size
    for update skip locked
  ), updated as (
    update region_activation_state ras
    set
      state = 'dormant',
      is_dormant = true,
      dormant_at = now(),
      last_dormant_transition_at = now(),
      dormancy_reason = v_reason,
      retention_until = now() + make_interval(days => v_retention_days)
    where ras.id in (select c.id from candidates c)
    returning ras.id
  )
  select count(*) into v_updated from updated;

  return v_updated;
end;
$$;

create or replace function public.mark_expired_dormant_regions_archived(
  input_batch_size integer default 500,
  input_reason text default 'retention_elapsed'
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_batch_size integer := greatest(1, least(coalesce(input_batch_size, 500), 2000));
  v_reason text := coalesce(nullif(btrim(input_reason), ''), 'retention_elapsed');
  v_updated integer := 0;
begin
  if auth.role() <> 'service_role' then
    raise exception 'forbidden';
  end if;

  with candidates as (
    select ras.id
    from region_activation_state ras
    where ras.state = 'dormant'
      and ras.retention_until is not null
      and ras.retention_until <= now()
    order by ras.retention_until asc
    limit v_batch_size
    for update skip locked
  ), updated as (
    update region_activation_state ras
    set
      state = 'archived',
      archived_at = now(),
      is_dormant = true,
      dormancy_reason = coalesce(ras.dormancy_reason, v_reason)
    where ras.id in (select c.id from candidates c)
    returning ras.id
  )
  select count(*) into v_updated from updated;

  return v_updated;
end;
$$;

drop function if exists public.activate_region_and_roll_encounter(text, integer, text, text);

create or replace function public.activate_region_and_roll_encounter(
  input_geohash text,
  input_precision integer default 7,
  input_country_code text default null,
  input_density_tier text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_region_id uuid;
  v_is_new_region boolean := false;
  v_now timestamptz := now();
  v_last_encounter_at timestamptz;
  v_cooldown_minutes integer := 15;
  v_cooldown_active boolean := false;
  v_cooldown_remaining integer := 0;
  v_density_tier text := 'unknown';
  v_probability numeric := 0.2;
  v_probability_multiplier numeric := 1;
  v_roll numeric;
  v_encountered boolean := false;
  v_cat_id uuid;
  v_cat_internal_name text;
  v_cat_display_name text;
  v_encounter_event_id uuid;
  v_encounter_happened_at timestamptz;
  v_country_code text;
  v_override_density_tier text;
  v_override_support_level numeric(6,2);
  v_override_risk_level numeric(6,2);
  v_previous_state text;
  v_was_reactivated boolean := false;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'auth_required';
  end if;

  if input_geohash is null or btrim(input_geohash) = '' then
    raise exception 'invalid_geohash';
  end if;

  if input_precision < 1 or input_precision > 12 then
    raise exception 'invalid_precision';
  end if;

  v_country_code := upper(nullif(btrim(input_country_code), ''));

  if v_country_code is not null then
    select density_tier, support_level, risk_level, spawn_probability_multiplier
    into v_override_density_tier, v_override_support_level, v_override_risk_level, v_probability_multiplier
    from region_country_overrides
    where region_code = v_country_code;
  end if;

  select id into v_region_id
  from regions
  where geohash = input_geohash;

  if v_region_id is null then
    insert into regions (
      geohash,
      geohash_precision,
      density_tier,
      support_level,
      risk_level
    )
    values (
      input_geohash,
      input_precision,
      coalesce(nullif(input_density_tier, ''), v_override_density_tier, 'suburban'),
      coalesce(v_override_support_level, 0),
      coalesce(v_override_risk_level, 0)
    )
    returning id, density_tier into v_region_id, v_density_tier;
    v_is_new_region := true;
  else
    select density_tier into v_density_tier
    from regions
    where id = v_region_id;

    if v_density_tier = 'unknown' then
      update regions
      set density_tier = coalesce(nullif(input_density_tier, ''), v_override_density_tier, density_tier),
          support_level = case when v_override_support_level is not null then v_override_support_level else support_level end,
          risk_level = case when v_override_risk_level is not null then v_override_risk_level else risk_level end,
          updated_at = v_now
      where id = v_region_id
      returning density_tier into v_density_tier;
    end if;
  end if;

  select state into v_previous_state
  from region_activation_state
  where region_id = v_region_id;

  insert into region_activation_state (
    region_id,
    activated_by_user_id,
    activated_at,
    last_simulated_at,
    is_dormant,
    state,
    activation_count,
    last_activated_at
  )
  values (
    v_region_id,
    v_user_id,
    v_now,
    v_now,
    false,
    'active',
    1,
    v_now
  )
  on conflict (region_id)
  do update set
    activated_by_user_id = excluded.activated_by_user_id,
    activated_at = excluded.activated_at,
    last_simulated_at = excluded.last_simulated_at,
    is_dormant = false,
    state = 'active',
    dormant_at = null,
    archived_at = null,
    dormancy_reason = null,
    retention_until = null,
    last_activated_at = v_now,
    last_reactivated_at = case
      when region_activation_state.state = 'active' then region_activation_state.last_reactivated_at
      else v_now
    end,
    activation_count = case
      when region_activation_state.state = 'active' then region_activation_state.activation_count
      else region_activation_state.activation_count + 1
    end;

  v_was_reactivated := v_previous_state is not null and v_previous_state <> 'active';

  select happened_at into v_last_encounter_at
  from encounter_events
  where user_id = v_user_id
  order by happened_at desc
  limit 1;

  select coalesce((config_value #>> '{}')::integer, 15) into v_cooldown_minutes
  from balance_configs bc
  join balance_config_sets bcs on bcs.id = bc.config_set_id
  where bcs.is_active = true
    and bc.category = 'spawn'
    and bc.config_key = 'cooldown_minutes'
  order by case when bcs.scope = 'global' then 1 else 2 end
  limit 1;

  if v_last_encounter_at is not null then
    if v_now < v_last_encounter_at + make_interval(mins => v_cooldown_minutes) then
      v_cooldown_active := true;
      v_cooldown_remaining := extract(epoch from ((v_last_encounter_at + make_interval(mins => v_cooldown_minutes)) - v_now))::integer;
    end if;
  end if;

  if not v_cooldown_active then
    select coalesce((bc.config_value ->> v_density_tier)::numeric, 0.2) into v_probability
    from balance_configs bc
    join balance_config_sets bcs on bcs.id = bc.config_set_id
    where bcs.is_active = true
      and (
        bcs.scope = 'global'
        or (v_country_code is not null and bcs.scope = 'region' and bcs.region_code = v_country_code)
      )
      and bc.category = 'spawn'
      and bc.config_key = 'encounter_probability_by_density'
    order by case when bcs.scope = 'region' and bcs.region_code = v_country_code then 0 else 1 end
    limit 1;

    v_probability := greatest(0, least(1, v_probability * coalesce(v_probability_multiplier, 1)));
    v_roll := random();

    if v_roll <= v_probability then
      v_encountered := true;

      select c.id, c.internal_name, c.display_name
      into v_cat_id, v_cat_internal_name, v_cat_display_name
      from cats c
      where c.current_region_id = v_region_id
        and c.is_alive = true
        and c.status = 'stray'
      order by random()
      limit 1;

      if v_cat_id is null then
        insert into cats (
          internal_name,
          status,
          ownership_state,
          origin_region_id,
          current_region_id,
          is_alive,
          is_castrated,
          is_microchipped,
          gender
        )
        values (
          'Stray-' || substring(gen_random_uuid()::text from 1 for 8),
          'stray',
          'unowned',
          v_region_id,
          v_region_id,
          true,
          false,
          false,
          (array['female','male','unknown'])[1 + floor(random() * 3)::int]
        )
        returning id, internal_name, display_name into v_cat_id, v_cat_internal_name, v_cat_display_name;
      end if;

      insert into encounter_events (user_id, cat_id, region_id, encounter_type, trust_delta, happened_at)
      values (v_user_id, v_cat_id, v_region_id, 'nearby', 0, v_now)
      returning id, happened_at into v_encounter_event_id, v_encounter_happened_at;
    end if;
  end if;

  return jsonb_build_object(
    'region_id', v_region_id,
    'region_geohash', input_geohash,
    'country_code', v_country_code,
    'density_tier', v_density_tier,
    'region_state', 'active',
    'was_reactivated', v_was_reactivated,
    'is_new_region', v_is_new_region,
    'cooldown_active', v_cooldown_active,
    'cooldown_remaining_seconds', greatest(v_cooldown_remaining, 0),
    'encounter_rolled', v_encountered,
    'encounter_event_id', v_encounter_event_id,
    'encounter_happened_at', v_encounter_happened_at,
    'cat_id', v_cat_id,
    'cat_internal_name', v_cat_internal_name,
    'cat_display_name', v_cat_display_name
  );
end;
$$;

revoke all on function public.resolve_region_dormancy_retention_days(integer) from public;
revoke all on function public.mark_stale_regions_dormant(integer, integer, text, integer) from public;
revoke all on function public.mark_expired_dormant_regions_archived(integer, text) from public;
revoke all on function public.activate_region_and_roll_encounter(text, integer, text, text) from public;

grant execute on function public.resolve_region_dormancy_retention_days(integer) to service_role;
grant execute on function public.mark_stale_regions_dormant(integer, integer, text, integer) to service_role;
grant execute on function public.mark_expired_dormant_regions_archived(integer, text) to service_role;
grant execute on function public.activate_region_and_roll_encounter(text, integer, text, text) to authenticated;
