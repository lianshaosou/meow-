#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${REGION_LIFECYCLE_WORKER_URL:-}" ]]; then
  echo "REGION_LIFECYCLE_WORKER_URL is required"
  exit 1
fi

if [[ -z "${REGION_LIFECYCLE_WORKER_BEARER:-}" ]]; then
  echo "REGION_LIFECYCLE_WORKER_BEARER is required"
  exit 1
fi

payload='{"idleHours":72,"batchSize":500,"runArchiveSweep":true}'

response="$(curl -sS -X POST "$REGION_LIFECYCLE_WORKER_URL" \
  -H "Authorization: Bearer $REGION_LIFECYCLE_WORKER_BEARER" \
  -H "Content-Type: application/json" \
  -d "$payload")"

echo "$response"

if [[ "$response" != *"dormantMarked"* ]] || [[ "$response" != *"archivedMarked"* ]]; then
  echo "Unexpected region lifecycle worker response payload"
  exit 1
fi

echo "Region lifecycle worker smoke check passed"
