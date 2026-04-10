# APNs Push Worker Runbook

This worker consumes `push_delivery_jobs`, sends APNs provider requests, and marks job outcomes.

## Required Inputs
- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `APNS_TOPIC` (bundle identifier)
- Auth token strategy:
  - Preferred: in-worker JWT minting (`APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_PRIVATE_KEY_P8`)
  - Fallback: static `APNS_AUTH_BEARER_TOKEN`

## Worker Loop
1. Recover stale `processing` jobs via `recover_stale_push_delivery_jobs`.
2. Claim jobs via `claim_push_delivery_jobs`.
3. POST to APNs endpoint: `/3/device/<token>`.
4. Mark success with `mark_push_delivery_job_sent`.
5. Mark failure with `mark_push_delivery_job_failed` and a retry delay.
6. For permanent token failures (`410`, `Unregistered`, `BadDeviceToken`, `DeviceTokenNotForTopic`), call `deactivate_push_token_for_job`.

## Recover Stale Locks Example

```sql
select recover_stale_push_delivery_jobs(
  input_lock_timeout_seconds => 300,
  input_max_attempts => 5
);
```

## Claim Jobs Example

```sql
select *
from claim_push_delivery_jobs(
  input_batch_size => 50,
  input_worker_id => 'apns-worker-1',
  input_max_attempts => 5
);
```

## Mark Success Example

```sql
select mark_push_delivery_job_sent(
  input_job_id => '<job-uuid>',
  input_provider_response => '{"apns_id":"<apns-id>","status":200}'::jsonb
);
```

## Mark Failure Example

```sql
select mark_push_delivery_job_failed(
  input_job_id => '<job-uuid>',
  input_error => 'TooManyRequests',
  input_retry_delay_seconds => 120,
  input_max_attempts => 5,
  input_provider_response => '{"status":429,"reason":"TooManyRequests"}'::jsonb
);
```

## Retry Behavior
- Worker increments attempts on claim.
- `mark_push_delivery_job_failed` requeues until `attempts >= input_max_attempts`.
- Terminal failures remain `failed` with `processed_at` and `last_error` set.
- `recover_stale_push_delivery_jobs` requeues stale `processing` jobs if workers crash mid-flight.
- `deactivate_push_token_for_job` deactivates invalid tokens and marks queued/processing jobs for that token as terminal failed.

## Scheduling Strategy
- Invoke worker every 1 minute with `batchSize` tuned to expected throughput.
- Keep invocations idempotent; claim RPC uses row locks (`for update skip locked`) to prevent double processing.
- Suggested first rollout:
  - schedule: every minute
  - `batchSize`: 50
  - `maxAttempts`: 5
  - alert on queued job age > 5 minutes or failure rate > 2%

## Token Rotation Strategy
- Preferred: key-based minting in worker.
  - Worker creates fresh ES256 APNs JWT and caches it for `APNS_AUTH_TOKEN_TTL_SECONDS` (default 3000s).
  - Rotate `.p8` key by updating secrets, then redeploy/restart function instances.
- Fallback: static bearer token.
  - Rotate at least every 50 minutes (APNs JWT max validity is 60 minutes).
  - Not recommended for steady-state production.
