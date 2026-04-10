with inserted_set as (
  insert into balance_config_sets (key, description, scope, is_active, activated_at)
  values (
    'global-default-v1',
    'Initial global tuning defaults for encounters, medical progression, incidents, and economy.',
    'global',
    true,
    now()
  )
  on conflict (key) do update
  set description = excluded.description,
      scope = excluded.scope,
      is_active = excluded.is_active,
      activated_at = excluded.activated_at
  returning id
)
insert into balance_configs (config_set_id, category, config_key, config_value)
select id, cfg.category, cfg.config_key, cfg.config_value
from inserted_set,
(
  values
    ('spawn', 'encounter_probability_by_density', '{"city":0.42,"suburban":0.28,"rural":0.17,"sparse":0.08}'::jsonb),
    ('spawn', 'territory_weighting', '{"origin_cell":0.50,"adjacent":0.30,"distant":0.20}'::jsonb),
    ('spawn', 'cooldown_minutes', '15'::jsonb),
    ('medical', 'base_condition_roll_daily', '{"stray":0.09,"pet":0.03}'::jsonb),
    ('medical', 'symptom_reveal_delay_hours', '{"min":3,"max":72}'::jsonb),
    ('medical', 'treatment_success_baseline', '0.74'::jsonb),
    ('incidents', 'daily_incident_roll', '{"pet":0.015,"stray":0.038}'::jsonb),
    ('incidents', 'night_alert_minimum_severity', '"high"'::jsonb),
    ('ecology', 'uncastrated_reproduction_multiplier', '1.65'::jsonb),
    ('ecology', 'station_survival_bonus', '0.18'::jsonb),
    ('economy', 'base_vet_checkup_cost', '25'::jsonb),
    ('economy', 'base_sterilization_cost', '40'::jsonb),
    ('economy', 'daily_food_cost', '4'::jsonb),
    ('economy', 'pet_hotel_daily_cost', '18'::jsonb)
) as cfg(category, config_key, config_value)
on conflict (config_set_id, category, config_key)
do update set config_value = excluded.config_value;
