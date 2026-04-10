with active_set as (
  select id
  from balance_config_sets
  where is_active = true
  order by case when scope = 'global' then 0 else 1 end, activated_at desc nulls last
  limit 1
)
insert into balance_configs (config_set_id, category, config_key, config_value)
select active_set.id, cfg.category, cfg.config_key, cfg.config_value
from active_set,
(
  values
    ('spawn', 'familiar_reencounter_probability_multiplier', '1.25'::jsonb),
    ('spawn', 'adjacent_roam_probability', '0.35'::jsonb)
) as cfg(category, config_key, config_value)
on conflict (config_set_id, category, config_key)
do update set config_value = excluded.config_value;

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
  v_familiar_reencounter_multiplier numeric := 1.25;
  v_adjacent_roam_probability numeric := 0.35;
  v_roll numeric;
  v_encountered boolean := false;
  v_cat_id uuid;
  v_cat_internal_name text;
  v_cat_display_name text;
  v_cat_region_id uuid;
  v_selected_cat_encounter_count integer := 0;
  v_encounter_event_id uuid;
  v_encounter_happened_at timestamptz;
  v_country_code text;
  v_override_density_tier text;
  v_override_support_level numeric(6,2);
  v_override_risk_level numeric(6,2);
  v_previous_state text;
  v_was_reactivated boolean := false;
  v_allow_adjacent_roam boolean := false;
  v_familiar_candidate_count integer := 0;
  v_adjacent_prefix text;
  v_adjacent_roam_used boolean := false;
  v_cat_source text := null;
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
  v_adjacent_prefix := left(input_geohash, greatest(char_length(input_geohash) - 1, 1));

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

  select coalesce((config_value #>> '{}')::numeric, 1.25) into v_familiar_reencounter_multiplier
  from balance_configs bc
  join balance_config_sets bcs on bcs.id = bc.config_set_id
  where bcs.is_active = true
    and bc.category = 'spawn'
    and bc.config_key = 'familiar_reencounter_probability_multiplier'
  order by case when bcs.scope = 'global' then 1 else 2 end
  limit 1;

  select coalesce((config_value #>> '{}')::numeric, 0.35) into v_adjacent_roam_probability
  from balance_configs bc
  join balance_config_sets bcs on bcs.id = bc.config_set_id
  where bcs.is_active = true
    and bc.category = 'spawn'
    and bc.config_key = 'adjacent_roam_probability'
  order by case when bcs.scope = 'global' then 1 else 2 end
  limit 1;

  v_familiar_reencounter_multiplier := greatest(1.0, least(v_familiar_reencounter_multiplier, 3.0));
  v_adjacent_roam_probability := greatest(0, least(v_adjacent_roam_probability, 1));

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

    select count(distinct ee.cat_id) into v_familiar_candidate_count
    from encounter_events ee
    join cats c on c.id = ee.cat_id
    join regions rr on rr.id = c.current_region_id
    where ee.user_id = v_user_id
      and c.is_alive = true
      and c.status = 'stray'
      and (
        c.current_region_id = v_region_id
        or rr.geohash like v_adjacent_prefix || '%'
      );

    v_probability := greatest(0, least(1, v_probability * coalesce(v_probability_multiplier, 1)));
    if v_familiar_candidate_count > 0 then
      v_probability := greatest(0, least(1, v_probability * v_familiar_reencounter_multiplier));
    end if;

    v_roll := random();
    if v_roll <= v_probability then
      v_encountered := true;
      v_allow_adjacent_roam := random() <= v_adjacent_roam_probability;

      with per_cat_history as (
        select
          ee.cat_id,
          count(*)::integer as encounter_count,
          max(ee.happened_at) as last_seen_at
        from encounter_events ee
        where ee.user_id = v_user_id
        group by ee.cat_id
      )
      select
        c.id,
        c.internal_name,
        c.display_name,
        c.current_region_id,
        coalesce(h.encounter_count, 0)
      into
        v_cat_id,
        v_cat_internal_name,
        v_cat_display_name,
        v_cat_region_id,
        v_selected_cat_encounter_count
      from cats c
      join regions candidate_region on candidate_region.id = c.current_region_id
      left join per_cat_history h on h.cat_id = c.id
      where c.is_alive = true
        and c.status = 'stray'
        and (
          c.current_region_id = v_region_id
          or (v_allow_adjacent_roam and candidate_region.geohash like v_adjacent_prefix || '%')
        )
      order by
        case when c.current_region_id = v_region_id then 0 else 1 end,
        case when coalesce(h.encounter_count, 0) > 0 then 0 else 1 end,
        coalesce(h.encounter_count, 0) desc,
        coalesce(h.last_seen_at, to_timestamp(0)) desc,
        random()
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
        returning id, internal_name, display_name, current_region_id
        into v_cat_id, v_cat_internal_name, v_cat_display_name, v_cat_region_id;
        v_selected_cat_encounter_count := 0;
      end if;

      if v_cat_region_id is distinct from v_region_id then
        v_adjacent_roam_used := true;
        update cats
        set current_region_id = v_region_id,
            updated_at = v_now
        where id = v_cat_id;
      end if;

      v_cat_source := case
        when v_selected_cat_encounter_count > 0 and v_adjacent_roam_used then 'familiar_adjacent_roam'
        when v_selected_cat_encounter_count > 0 then 'familiar_local'
        when v_adjacent_roam_used then 'adjacent_roam'
        else 'new_local'
      end;

      insert into encounter_events (user_id, cat_id, region_id, encounter_type, trust_delta, happened_at, metadata)
      values (
        v_user_id,
        v_cat_id,
        v_region_id,
        'nearby',
        0,
        v_now,
        jsonb_build_object(
          'cat_source', v_cat_source,
          'familiar_encounter_count', coalesce(v_selected_cat_encounter_count, 0),
          'adjacent_roam_used', v_adjacent_roam_used
        )
      )
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
    'cat_source', v_cat_source,
    'familiar_encounter_count', v_selected_cat_encounter_count,
    'adjacent_roam_used', v_adjacent_roam_used,
    'cat_id', v_cat_id,
    'cat_internal_name', v_cat_internal_name,
    'cat_display_name', v_cat_display_name
  );
end;
$$;

revoke all on function public.activate_region_and_roll_encounter(text, integer, text, text) from public;
grant execute on function public.activate_region_and_roll_encounter(text, integer, text, text) to authenticated;
