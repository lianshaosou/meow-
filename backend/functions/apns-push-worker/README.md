# apns-push-worker (Supabase Edge Function)

Consumes queued push jobs from `push_delivery_jobs`, calls APNs provider endpoint, and marks success/failure.

## Environment
- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `APNS_TOPIC` (bundle id)
- Auth token strategy (pick one):
  - Preferred: JWT minting in-function
    - `APNS_KEY_ID`
    - `APNS_TEAM_ID`
    - `APNS_PRIVATE_KEY_P8` (escaped newlines allowed)
    - `APNS_AUTH_TOKEN_TTL_SECONDS` (optional, default `3000`)
  - Fallback: pre-minted token
    - `APNS_AUTH_BEARER_TOKEN`

## Deploy

```bash
supabase functions deploy apns-push-worker
```

## Invoke

```bash
curl -X POST "https://<project-ref>.functions.supabase.co/apns-push-worker" \
  -H "Authorization: Bearer <service-role-key-or-function-jwt>" \
  -H "Content-Type: application/json" \
  -d '{"batchSize":50,"maxAttempts":5,"lockTimeoutSeconds":300,"workerID":"apns-worker-1"}'
```

Returns:
- `recovered`: stale locked jobs requeued/closed before claim
- `claimed`: number of jobs claimed
- `sent`: number sent successfully
- `failed`: number failed/requeued

## Notes
- Pair with migration `0009_push_delivery_provider_worker.sql`.
- Pair with migration `0010_push_delivery_stale_lock_recovery.sql` for stale lock cleanup.
- Pair with migration `0011_push_dead_token_remediation.sql` for invalid token deactivation.
- Pair with migration `0012_fix_push_claim_rpc_ambiguity.sql` for stable claim RPC execution.
- For production reliability, schedule periodic invocation and monitor `push_delivery_jobs` failure rates.
- Recommended rotation strategy is key-based JWT minting (`APNS_KEY_ID` + `APNS_TEAM_ID` + `APNS_PRIVATE_KEY_P8`) so worker always uses fresh APNs auth tokens.

## Tests

```bash
deno test backend/functions/apns-push-worker/worker_utils_test.ts backend/functions/apns-push-worker/worker_core_test.ts
```

Staging smoke helper:

```bash
APNS_WORKER_SMOKE_URL=https://<project-ref>.functions.supabase.co/apns-push-worker \
APNS_WORKER_SMOKE_BEARER=<service-role-or-function-jwt> \
bash backend/live_ops/apns_worker_smoke.sh
```
