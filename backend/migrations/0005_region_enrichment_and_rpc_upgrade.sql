create table if not exists region_country_overrides (
  region_code text primary key,
  density_tier text not null,
  support_level numeric(6,2) not null default 0,
  risk_level numeric(6,2) not null default 0,
  spawn_probability_multiplier numeric(6,3) not null default 1,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into region_country_overrides (region_code, density_tier, support_level, risk_level, spawn_probability_multiplier)
values
  ('US', 'suburban', 0.30, 0.20, 1.00),
  ('JP', 'city', 0.42, 0.12, 1.12),
  ('BR', 'city', 0.26, 0.31, 1.08),
  ('IN', 'city', 0.22, 0.35, 1.10),
  ('SE', 'suburban', 0.48, 0.10, 0.92)
on conflict (region_code) do update
set
  density_tier = excluded.density_tier,
  support_level = excluded.support_level,
  risk_level = excluded.risk_level,
  spawn_probability_multiplier = excluded.spawn_probability_multiplier,
  updated_at = now();

drop function if exists public.activate_region_and_roll_encounter(text, integer);

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

  insert into region_activation_state (region_id, activated_by_user_id, activated_at, last_simulated_at, is_dormant)
  values (v_region_id, v_user_id, v_now, v_now, false)
  on conflict (region_id)
  do update set
    activated_by_user_id = excluded.activated_by_user_id,
    last_simulated_at = excluded.last_simulated_at,
    is_dormant = false;

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

revoke all on function public.activate_region_and_roll_encounter(text, integer, text, text) from public;
grant execute on function public.activate_region_and_roll_encounter(text, integer, text, text) to authenticated;
