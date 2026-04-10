create or replace function public.activate_region_and_roll_encounter(
  input_geohash text,
  input_precision integer default 7
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
  v_roll numeric;
  v_encountered boolean := false;
  v_cat_id uuid;
  v_cat_internal_name text;
  v_cat_display_name text;
  v_encounter_event_id uuid;
  v_encounter_happened_at timestamptz;
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

  select id into v_region_id
  from regions
  where geohash = input_geohash;

  if v_region_id is null then
    insert into regions (geohash, geohash_precision, density_tier)
    values (input_geohash, input_precision, 'unknown')
    returning id into v_region_id;
    v_is_new_region := true;
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
  limit 1;

  if v_last_encounter_at is not null then
    if v_now < v_last_encounter_at + make_interval(mins => v_cooldown_minutes) then
      v_cooldown_active := true;
      v_cooldown_remaining := extract(epoch from ((v_last_encounter_at + make_interval(mins => v_cooldown_minutes)) - v_now))::integer;
    end if;
  end if;

  if not v_cooldown_active then
    select density_tier into v_density_tier
    from regions
    where id = v_region_id;

    select coalesce((bc.config_value ->> v_density_tier)::numeric, 0.2) into v_probability
    from balance_configs bc
    join balance_config_sets bcs on bcs.id = bc.config_set_id
    where bcs.is_active = true
      and bc.category = 'spawn'
      and bc.config_key = 'encounter_probability_by_density'
    limit 1;

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

revoke all on function public.activate_region_and_roll_encounter(text, integer) from public;
grant execute on function public.activate_region_and_roll_encounter(text, integer) to authenticated;
