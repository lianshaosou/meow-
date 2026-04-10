-- Enable RLS on all user-scoped tables.
alter table profiles enable row level security;
alter table homes enable row level security;
alter table home_change_tokens enable row level security;
alter table cat_medical_known_state enable row level security;
alter table encounter_events enable row level security;
alter table adoption_records enable row level security;
alter table care_actions enable row level security;
alter table absence_plans enable row level security;
alter table notification_preferences enable row level security;
alter table notification_events enable row level security;
alter table death_records enable row level security;
alter table memorials enable row level security;
alter table station_funding enable row level security;
alter table economy_transactions enable row level security;
alter table inventory_items enable row level security;
alter table service_records enable row level security;
alter table time_state_snapshots enable row level security;

-- Public read tables for world simulation and tuning.
alter table regions enable row level security;
alter table region_activation_state enable row level security;
alter table cats enable row level security;
alter table cat_lineage enable row level security;
alter table cat_traits enable row level security;
alter table cat_appearance enable row level security;
alter table cat_behavior_profiles enable row level security;
alter table cat_medical_true_state enable row level security;
alter table incident_events enable row level security;
alter table stations enable row level security;
alter table station_maintenance enable row level security;
alter table simulation_events enable row level security;
alter table balance_config_sets enable row level security;
alter table balance_configs enable row level security;

create policy "profiles_select_own"
on profiles for select using (auth.uid() = id);

create policy "profiles_update_own"
on profiles for update using (auth.uid() = id);

create policy "homes_owner_all"
on homes for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "home_tokens_owner_all"
on home_change_tokens for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "cat_medical_known_owner_all"
on cat_medical_known_state for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "encounters_owner_all"
on encounter_events for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "adoptions_owner_all"
on adoption_records for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "care_actions_owner_all"
on care_actions for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "absence_plans_owner_all"
on absence_plans for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "notification_preferences_owner_all"
on notification_preferences for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "notification_events_owner_all"
on notification_events for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "death_records_owner_all"
on death_records for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "memorials_owner_all"
on memorials for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "station_funding_owner_all"
on station_funding for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "economy_transactions_owner_all"
on economy_transactions for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "inventory_items_owner_all"
on inventory_items for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "service_records_owner_all"
on service_records for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "time_state_snapshots_owner_all"
on time_state_snapshots for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "regions_world_read"
on regions for select using (true);

create policy "region_activation_world_read"
on region_activation_state for select using (true);

create policy "cats_world_read"
on cats for select using (true);

create policy "cat_lineage_world_read"
on cat_lineage for select using (true);

create policy "cat_traits_world_read"
on cat_traits for select using (true);

create policy "cat_appearance_world_read"
on cat_appearance for select using (true);

create policy "cat_behavior_world_read"
on cat_behavior_profiles for select using (true);

create policy "cat_medical_true_service_only"
on cat_medical_true_state for select using (auth.role() = 'service_role');

create policy "incident_events_world_read"
on incident_events for select using (true);

create policy "stations_world_read"
on stations for select using (true);

create policy "station_maintenance_world_read"
on station_maintenance for select using (true);

create policy "simulation_events_service_read"
on simulation_events for select using (auth.role() = 'service_role');

create policy "balance_sets_world_read"
on balance_config_sets for select using (true);

create policy "balance_configs_world_read"
on balance_configs for select using (true);
