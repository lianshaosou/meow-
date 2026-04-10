#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${APNS_WORKER_SMOKE_URL:-}" ]]; then
  echo "APNS_WORKER_SMOKE_URL is required"
  exit 1
fi

if [[ -z "${APNS_WORKER_SMOKE_BEARER:-}" ]]; then
  echo "APNS_WORKER_SMOKE_BEARER is required"
  exit 1
fi

payload='{"batchSize":5,"maxAttempts":3,"lockTimeoutSeconds":300,"workerID":"apns-smoke"}'

response="$(curl -sS -X POST "$APNS_WORKER_SMOKE_URL" \
  -H "Authorization: Bearer $APNS_WORKER_SMOKE_BEARER" \
  -H "Content-Type: application/json" \
  -d "$payload")"

echo "$response"

if [[ "$response" != *"claimed"* ]] || [[ "$response" != *"sent"* ]] || [[ "$response" != *"failed"* ]]; then
  echo "Unexpected smoke response payload"
  exit 1
fi

echo "APNs worker smoke check passed"
