#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${STAGING_PROJECT_REF:-}" ]]; then
  echo "STAGING_PROJECT_REF is required"
  exit 1
fi

supabase link --project-ref "$STAGING_PROJECT_REF" --workdir . >/dev/null

raw_json="$(supabase db query --linked --workdir . --output json -f backend/analytics/ops_alert_checks.sql)"
echo "$raw_json"

alert_payload="$(echo "$raw_json" | jq '.[0]')"

if [[ "$alert_payload" == "null" || -z "$alert_payload" ]]; then
  echo "Could not parse alert payload"
  exit 1
fi

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "alert_payload<<EOF"
    echo "$alert_payload"
    echo "EOF"
  } >> "$GITHUB_OUTPUT"
fi

has_alert="$(echo "$alert_payload" | jq '[.[]] | any(. == true)')"

if [[ "$has_alert" != "true" ]]; then
  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    echo "alert_active=false" >> "$GITHUB_OUTPUT"
  fi
  echo "No active alerts"
  exit 0
fi

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "alert_active=true" >> "$GITHUB_OUTPUT"
fi

echo "One or more alerts are active"

if [[ -n "${OPS_ALERT_WEBHOOK_URL:-}" ]]; then
  webhook_body="$(jq -n --argjson alerts "$alert_payload" '{text:"Meow ops alerts active", alerts:$alerts}')"
  curl -sS -X POST "$OPS_ALERT_WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -d "$webhook_body" >/dev/null
  echo "Posted alert payload to webhook"
fi
exit 0
