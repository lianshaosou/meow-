alter table region_country_overrides
  alter column region_code type text using upper(region_code);

create or replace function public.touch_region_country_override_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists region_country_overrides_touch_updated_at on region_country_overrides;
create trigger region_country_overrides_touch_updated_at
before update on region_country_overrides
for each row
execute function public.touch_region_country_override_updated_at();

create or replace function public.list_region_country_overrides(
  input_region_code text default null,
  input_limit integer default 200,
  input_offset integer default 0
)
returns table (
  region_code text,
  density_tier text,
  support_level numeric,
  risk_level numeric,
  spawn_probability_multiplier numeric,
  metadata jsonb,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_region_code text := upper(nullif(btrim(input_region_code), ''));
  v_limit integer := greatest(1, least(coalesce(input_limit, 200), 500));
  v_offset integer := greatest(0, coalesce(input_offset, 0));
begin
  if auth.role() <> 'service_role' then
    raise exception 'forbidden';
  end if;

  return query
  select
    rco.region_code,
    rco.density_tier,
    rco.support_level,
    rco.risk_level,
    rco.spawn_probability_multiplier,
    rco.metadata,
    rco.created_at,
    rco.updated_at
  from region_country_overrides rco
  where v_region_code is null or rco.region_code = v_region_code
  order by rco.region_code asc
  limit v_limit
  offset v_offset;
end;
$$;

create or replace function public.upsert_region_country_override(
  input_region_code text,
  input_density_tier text,
  input_support_level numeric,
  input_risk_level numeric,
  input_spawn_probability_multiplier numeric,
  input_metadata jsonb default '{}'::jsonb
)
returns region_country_overrides
language plpgsql
security definer
set search_path = public
as $$
declare
  v_region_code text := upper(nullif(btrim(input_region_code), ''));
  v_density_tier text := lower(nullif(btrim(input_density_tier), ''));
  v_support_level numeric := coalesce(input_support_level, 0);
  v_risk_level numeric := coalesce(input_risk_level, 0);
  v_spawn_multiplier numeric := coalesce(input_spawn_probability_multiplier, 1);
  v_metadata jsonb := coalesce(input_metadata, '{}'::jsonb);
  v_row region_country_overrides;
begin
  if auth.role() <> 'service_role' then
    raise exception 'forbidden';
  end if;

  if v_region_code is null then
    raise exception 'invalid_region_code';
  end if;
  if v_density_tier is null then
    raise exception 'invalid_density_tier';
  end if;
  if v_support_level < 0 or v_support_level > 1 then
    raise exception 'invalid_support_level';
  end if;
  if v_risk_level < 0 or v_risk_level > 1 then
    raise exception 'invalid_risk_level';
  end if;
  if v_spawn_multiplier < 0 or v_spawn_multiplier > 3 then
    raise exception 'invalid_spawn_probability_multiplier';
  end if;

  insert into region_country_overrides (
    region_code,
    density_tier,
    support_level,
    risk_level,
    spawn_probability_multiplier,
    metadata
  )
  values (
    v_region_code,
    v_density_tier,
    v_support_level,
    v_risk_level,
    v_spawn_multiplier,
    v_metadata
  )
  on conflict (region_code)
  do update set
    density_tier = excluded.density_tier,
    support_level = excluded.support_level,
    risk_level = excluded.risk_level,
    spawn_probability_multiplier = excluded.spawn_probability_multiplier,
    metadata = excluded.metadata,
    updated_at = now()
  returning * into v_row;

  return v_row;
end;
$$;

create or replace function public.delete_region_country_override(input_region_code text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_region_code text := upper(nullif(btrim(input_region_code), ''));
  v_deleted integer;
begin
  if auth.role() <> 'service_role' then
    raise exception 'forbidden';
  end if;

  if v_region_code is null then
    raise exception 'invalid_region_code';
  end if;

  delete from region_country_overrides
  where region_code = v_region_code;

  get diagnostics v_deleted = row_count;
  return v_deleted > 0;
end;
$$;

revoke all on function public.list_region_country_overrides(text, integer, integer) from public;
revoke all on function public.upsert_region_country_override(text, text, numeric, numeric, numeric, jsonb) from public;
revoke all on function public.delete_region_country_override(text) from public;

grant execute on function public.list_region_country_overrides(text, integer, integer) to service_role;
grant execute on function public.upsert_region_country_override(text, text, numeric, numeric, numeric, jsonb) to service_role;
grant execute on function public.delete_region_country_override(text) to service_role;
