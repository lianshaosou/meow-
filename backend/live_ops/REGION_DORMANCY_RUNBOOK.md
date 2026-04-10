# Region Dormancy Runbook

This runbook covers P2 region lifecycle operations.

## Lifecycle States
- `active`: region is currently active and simulation-ready.
- `dormant`: region has been idle for configured period; retained for reactivation.
- `archived`: dormant retention elapsed; no hard delete in current policy.

## Retention Policy
- Retention days are read from balance config key:
  - category: `simulation`
  - key: `region_dormancy_retention_days`
- Default fallback when missing: `30` days.

## Mark Stale Regions Dormant

```sql
select mark_stale_regions_dormant(
  input_idle_hours => 72,
  input_batch_size => 500,
  input_reason => 'idle_timeout',
  input_retention_days => null
);
```

## Mark Expired Dormant Regions Archived

```sql
select mark_expired_dormant_regions_archived(
  input_batch_size => 500,
  input_reason => 'retention_elapsed'
);
```

## Reactivation Behavior
- `activate_region_and_roll_encounter` automatically reactivates dormant/archived activation state.
- Response now includes:
  - `region_state` (always `active` after call)
  - `was_reactivated` (true when prior state was not `active`)

## Suggested Scheduling
- Dormancy sweep: every hour.
- Archive sweep: every 6-24 hours.
