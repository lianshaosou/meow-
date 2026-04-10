#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${STAGING_PROJECT_REF:-}" ]]; then
  echo "STAGING_PROJECT_REF is required"
  exit 1
fi

supabase link --project-ref "$STAGING_PROJECT_REF" --workdir .

for migration in \
  "backend/migrations/0009_push_delivery_provider_worker.sql" \
  "backend/migrations/0010_push_delivery_stale_lock_recovery.sql" \
  "backend/migrations/0011_push_dead_token_remediation.sql" \
  "backend/migrations/0012_fix_push_claim_rpc_ambiguity.sql"
do
  echo "Applying ${migration}"
  supabase db query --linked --workdir . -f "$migration"
done

echo "Running push worker RPC verification"
supabase db query --linked --workdir . -f "backend/live_ops/push_worker_staging_verify.sql"

echo "Push worker staging checks passed"
